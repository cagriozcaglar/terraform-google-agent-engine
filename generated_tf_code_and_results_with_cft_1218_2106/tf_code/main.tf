# Provides access to the default provider configuration.
data "google_client_config" "default" {}

# Retrieves project information.
data "google_project" "project" {
  # The project ID to retrieve information for.
  project_id = local.project_id
  depends_on = [google_project_service.cloudresourcemanager]
}

locals {
  # Determine the project ID to use. Prioritize the variable, fall back to the provider's project.
  project_id = coalesce(var.project_id, data.google_client_config.default.project)

  # Determines the service account email to use, either from a newly created SA or a provided one.
  agent_sa_email = var.service_account_create ? google_service_account.agent_engine_sa[0].email : var.service_account_email

  # Determines the fully qualified service account name for IAM bindings.
  agent_sa_name = var.service_account_create ? google_service_account.agent_engine_sa[0].name : "projects/${local.project_id}/serviceAccounts/${var.service_account_email}"

  # Constructs the member identifier for the Eventarc service agent.
  eventarc_sa_member = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-eventarc.iam.gserviceaccount.com"

  # Constructs the member identifier for the Pub/Sub service agent.
  pubsub_sa_member = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# Enables the necessary APIs for the module to function correctly.
resource "google_project_service" "iam" {
  project                    = local.project_id
  service                    = "iam.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "cloudresourcemanager" {
  project                    = local.project_id
  service                    = "cloudresourcemanager.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "pubsub" {
  project                    = local.project_id
  service                    = "pubsub.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "run" {
  project                    = local.project_id
  service                    = "run.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "eventarc" {
  project                    = local.project_id
  service                    = "eventarc.googleapis.com"
  disable_dependent_services = true
}

resource "google_project_service" "secretmanager" {
  # This is only needed if secrets are used, but enabling it by default is safer.
  project                    = local.project_id
  service                    = "secretmanager.googleapis.com"
  disable_dependent_services = true
}

# Defines the identity for the serverless agent to interact with other GCP services.
resource "google_service_account" "agent_engine_sa" {
  # Conditionally create this resource based on the `service_account_create` variable.
  count = var.service_account_create ? 1 : 0

  # The project in which the service account will be created.
  project = local.project_id

  # The unique ID for the service account.
  account_id = "${var.name}-agent-sa"

  # A user-friendly name for the service account.
  display_name = "Service Account for ${var.name} Agent Engine"

  # Explicitly depend on the IAM API being enabled.
  depends_on = [google_project_service.iam]
}

# The Pub/Sub topic that will act as the task queue for the Agent_Engine.
resource "google_pubsub_topic" "agent_tasks" {
  # The project in which the topic will be created.
  project = local.project_id

  # The name of the Pub/Sub topic.
  name = "${var.name}-tasks"

  # Explicitly depend on the Pub/Sub API being enabled.
  depends_on = [google_project_service.pubsub]
}

# The core of the Agent_Engine: a serverless Cloud Run service.
# It scales based on incoming requests and can scale down to zero when idle.
resource "google_cloud_run_v2_service" "agent_engine_service" {
  # The project in which the service will be created.
  project = local.project_id

  # The name of the Cloud Run service.
  name = "${var.name}-agent-service"

  # The location (region) for the Cloud Run service.
  location = var.location

  # The configuration template for new revisions of the service.
  template {
    # The scaling configuration for the service.
    scaling {
      # The maximum number of container instances that can be started for this service.
      max_instance_count = var.cloud_run_service_params.max_scale
      # The minimum number of container instances that will be kept warm.
      min_instance_count = var.cloud_run_service_params.min_scale
    }

    # The maximum number of concurrent requests that can be sent to a container instance.
    max_instance_request_concurrency = var.cloud_run_service_params.max_instance_request_concurrency

    # The timeout for requests to the service, in seconds.
    timeout = "${var.cloud_run_service_params.timeout_seconds}s"

    # The service runs with the dedicated, least-privilege service account.
    service_account = local.agent_sa_email

    # The agent is packaged as a container image.
    containers {
      # The container image to deploy.
      image = var.agent_container_image

      # The memory limit for the container.
      resources {
        limits = {
          memory = var.cloud_run_service_params.available_memory
        }
      }

      # Defines dynamic environment variables for the container.
      dynamic "env" {
        for_each = var.cloud_run_service_params.env
        content {
          # The name of the environment variable.
          name = env.value.name
          # The value of the environment variable.
          value = env.value.value
        }
      }

      # Defines dynamic secret environment variables for the container.
      dynamic "volume_mounts" {
        for_each = var.cloud_run_service_params.secrets
        content {
          # The name of the volume to mount.
          name = lower(replace(volume_mounts.key, "_", "-"))
          # The path within the container to mount the secret.
          mount_path = "/etc/secrets/${lower(replace(volume_mounts.key, "_", "-"))}"
        }
      }
    }

    # Defines dynamic secret volumes to be mounted into the container.
    dynamic "volumes" {
      for_each = var.cloud_run_service_params.secrets
      content {
        # The name of the volume.
        name = lower(replace(volumes.key, "_", "-"))
        # The secret to mount.
        secret {
          # The ID of the secret in Secret Manager.
          secret = volumes.value.secret
          # The items (versions) of the secret to project as files.
          items {
            # The version of the secret to mount.
            version = volumes.value.version
            # The relative path of the secret file.
            path = lower(volumes.key)
          }
        }
      }
    }
  }

  # Explicitly depend on the Cloud Run and Secret Manager APIs being enabled.
  depends_on = [google_project_service.run, google_project_service.secretmanager]
}

# An Eventarc trigger to connect the Pub/Sub topic to the Cloud Run service.
# This invokes the Cloud Run service whenever a new message is published to the topic.
resource "google_eventarc_trigger" "agent_task_trigger" {
  # The project in which the trigger will be created.
  project = local.project_id

  # The name of the Eventarc trigger.
  name = "${var.name}-task-trigger"

  # The location (region) for the trigger.
  location = var.location

  # The criteria by which events are filtered for this trigger.
  matching_criteria {
    # The name of the event attribute to filter on.
    attribute = "type"
    # The value of the attribute to match.
    value = "google.cloud.pubsub.topic.v1.messagePublished"
  }

  # The destination where events should be sent.
  destination {
    # Specifies a Cloud Run service as the destination.
    cloud_run_service {
      # The name of the Cloud Run service.
      service = google_cloud_run_v2_service.agent_engine_service.name
      # The region where the Cloud Run service is located.
      region = google_cloud_run_v2_service.agent_engine_service.location
    }
  }

  # The transport mechanism used for event delivery.
  transport {
    # Specifies Pub/Sub as the transport.
    pubsub {
      # The ID of the Pub/Sub topic that will be used for transport.
      topic = google_pubsub_topic.agent_tasks.id
    }
  }

  # The service account that the trigger will use to invoke the destination service.
  service_account = local.agent_sa_email

  # Ensure the Eventarc API is enabled and all necessary IAM permissions are in place
  # before attempting to create the trigger to avoid race conditions.
  depends_on = [
    google_project_service.eventarc,
    google_service_account_iam_member.eventarc_sa_user,
    google_service_account_iam_member.pubsub_token_creator,
    google_cloud_run_v2_service_iam_member.eventarc_invoker
  ]
}

# Grant the Eventarc service agent permission to impersonate the trigger's service account.
# This is required for Eventarc to be able to invoke the Cloud Run destination.
resource "google_service_account_iam_member" "eventarc_sa_user" {
  # Conditionally create this resource based on the `grant_eventarc_sa_user_role` variable.
  count = var.grant_eventarc_sa_user_role ? 1 : 0

  # The fully-qualified name of the service account to apply policy to.
  service_account_id = local.agent_sa_name

  # The role to grant.
  role = "roles/iam.serviceAccountUser"

  # The principal to grant the role to. This is the P4SA for Eventarc.
  member = local.eventarc_sa_member
}

# Grant the Pub/Sub service account permission to create authentication tokens for the agent's service account.
# This is required for the authenticated push subscription managed by Eventarc.
resource "google_service_account_iam_member" "pubsub_token_creator" {
  # Conditionally create this resource based on the `grant_pubsub_token_creator_role` variable.
  count = var.grant_pubsub_token_creator_role ? 1 : 0

  # The fully-qualified name of the service account to apply policy to.
  service_account_id = local.agent_sa_name

  # The role to grant.
  role = "roles/iam.serviceAccountTokenCreator"

  # The principal to grant the role to. This is the P4SA for Pub/Sub.
  member = local.pubsub_sa_member
}

# Grant the Eventarc trigger's service account permission to invoke the Cloud Run service.
resource "google_cloud_run_v2_service_iam_member" "eventarc_invoker" {
  # The project where the Cloud Run service is located.
  project = google_cloud_run_v2_service.agent_engine_service.project

  # The location where the Cloud Run service is located.
  location = google_cloud_run_v2_service.agent_engine_service.location

  # The name of the Cloud Run service.
  name = google_cloud_run_v2_service.agent_engine_service.name

  # The role to grant. 'run.invoker' allows invoking the service.
  role = "roles/run.invoker"

  # The principal to grant the role to, which is the service account used by the agent and Eventarc trigger.
  member = "serviceAccount:${local.agent_sa_email}"
}
