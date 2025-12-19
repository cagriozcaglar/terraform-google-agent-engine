# This terraform module is used to provision a generic, container-based agent engine
# on Google Cloud Platform. It uses Cloud Run as the core serverless compute and provides
# flexible options for invocation, state management, and networking. The module can be
# configured to create agents for various use cases, including:
# - Event-driven processing (e.g., triggered by Cloud Storage events via Eventarc).
# - Scheduled tasks (e.g., cron jobs via Cloud Scheduler).
# - Publicly accessible web services or APIs.
# - Stateful services connected to a private Memorystore (Redis) instance.
#
# The module handles the creation of a dedicated service account, networking components
# like VPC Access Connectors, and the necessary IAM bindings to connect all components
# securely.

#
# --- Local Variables ---
#

locals {
  # Determine the project ID to use. Prioritize the variable, but fall back to the provider's configured project.
  project_id = var.project_id == null ? data.google_client_config.current.project : var.project_id

  # Determine the service account email to use for the Cloud Run service.
  # It's either the newly created one or the one provided via variables.
  agent_service_account_email = var.service_account_create ? one(google_service_account.agent).email : var.service_account_email

  # Environment variables for Redis, created only if Redis is enabled.
  redis_env_vars = var.enable_redis ? {
    REDIS_HOST = one(google_redis_instance.agent_cache).host
    REDIS_PORT = tostring(one(google_redis_instance.agent_cache).port)
  } : {}

  # Merge user-provided environment variables with Redis variables if Redis is enabled.
  # Redis variables take precedence to prevent accidental overrides.
  final_container_env_vars = merge(
    var.container_env_vars,
    local.redis_env_vars
  )
}

#
# --- Data Sources ---
#

# Data source to get the provider's configured project to be used as a default.
data "google_client_config" "current" {}

# The GCP project details.
data "google_project" "project" {
  # The GCP project ID for which to fetch details.
  project_id = local.project_id
}

#
# --- Core Identity and Access Management ---
#

# A dedicated Service Account for the Agent Engine to run with least privilege.
# Its creation is controlled by the 'service_account_create' variable.
resource "google_service_account" "agent" {
  # This resource will be created only if the 'service_account_create' variable is true.
  for_each = var.service_account_create ? { this = true } : {}

  # The GCP project where the service account will be created.
  project = local.project_id
  # A unique identifier for the service account.
  account_id = "${var.name}-sa"
  # A user-friendly name for the service account.
  display_name = "Service Account for ${var.name} Agent Engine"
}

# Grant specified IAM roles to the agent's service account at the project level.
# This allows the agent to interact with other GCP services as needed.
resource "google_project_iam_member" "agent_sa_roles" {
  # Creates an IAM binding for each role specified in the 'service_account_roles' variable.
  for_each = toset(var.service_account_roles)

  # The GCP project ID for the IAM binding.
  project = local.project_id
  # The IAM role to be granted.
  role = each.key
  # The service account that will be granted the role.
  member = "serviceAccount:${local.agent_service_account_email}"
}


#
# --- Networking (Conditional) ---
#

# Creates a Serverless VPC Access Connector to allow the Cloud Run service
# to communicate with resources within a VPC, such as the Redis instance.
resource "google_vpc_access_connector" "agent_connector" {
  # This resource is created only if 'enable_redis' is true.
  for_each = var.enable_redis ? { this = true } : {}

  # The GCP project ID for the connector.
  project = local.project_id
  # A unique name for the VPC Access Connector.
  name = "${var.name}-vpc-connector"
  # The region where the connector will be created.
  region = var.location
  # The name of the VPC network to connect to.
  network = var.network_config.network_name
  # A /28 CIDR range for the connector's internal IP addresses.
  ip_cidr_range = var.network_config.connector_cidr_range

  # Validate that network_config is provided when enable_redis is true.
  lifecycle {
    precondition {
      condition     = var.network_config != null
      error_message = "The 'network_config' variable must be set when 'enable_redis' is true."
    }
  }
}

#
# --- State Management (Conditional) ---
#

# Creates a Memorystore for Redis instance for stateful agent operations.
resource "google_redis_instance" "agent_cache" {
  # This resource is created only if 'enable_redis' is true.
  for_each = var.enable_redis ? { this = true } : {}

  # The GCP project ID for the Redis instance.
  project = local.project_id
  # A unique name for the Redis instance.
  name = "${var.name}-cache"
  # The region where the Redis instance will be created.
  region = var.location
  # The service tier for the Redis instance (e.g., BASIC or STANDARD_HA).
  tier = var.redis_config.tier
  # The memory capacity of the Redis instance in GiB.
  memory_size_gb = var.redis_config.memory_size_gb
  # The VPC network that is authorized to connect to the instance.
  authorized_network = "projects/${local.project_id}/global/networks/${var.network_config.network_name}"
  # The connection mode, DIRECT_PEERING is required for Serverless VPC Access.
  connect_mode = "DIRECT_PEERING"

  # Validate that network_config is provided when enable_redis is true.
  lifecycle {
    precondition {
      condition     = var.network_config != null
      error_message = "The 'network_config' variable must be set when 'enable_redis' is true."
    }
  }
}


#
# --- Core Compute Engine ---
#

# The core compute resource for the agent, a serverless and scalable Cloud Run service.
resource "google_cloud_run_v2_service" "agent_engine" {
  # The GCP project ID for the Cloud Run service.
  project = local.project_id
  # A unique name for the Cloud Run service.
  name = var.name
  # The region where the service will be deployed.
  location = var.location

  # Configuration for the service template.
  template {
    # The service account the Cloud Run instance will run as.
    service_account = local.agent_service_account_email
    # The autoscaling settings for the service.
    scaling {
      min_instance_count = var.scaling.min_instance_count
      max_instance_count = var.scaling.max_instance_count
    }
    # The container configuration.
    containers {
      # The container image to run.
      image = var.container_image
      # The ports the container exposes.
      ports {
        container_port = var.container_port
      }
      # A list of environment variables for the container.
      # This uses a dynamic block to iterate over the merged map of variables.
      dynamic "env" {
        for_each = local.final_container_env_vars
        content {
          name  = env.key
          value = env.value
        }
      }
    }

    # Conditionally adds a VPC access block if Redis is enabled.
    dynamic "vpc_access" {
      for_each = var.enable_redis ? { this = true } : {}
      content {
        # The ID of the VPC Access Connector.
        connector = one(google_vpc_access_connector.agent_connector).id
        # Egress traffic control. ALL_TRAFFIC allows the service to send traffic to the VPC.
        egress = "ALL_TRAFFIC"
      }
    }
  }

  # Validate that a service account is properly configured.
  lifecycle {
    precondition {
      condition     = var.service_account_create || var.service_account_email != null
      error_message = "The 'service_account_email' variable must be set when 'service_account_create' is false."
    }
  }
}


#
# --- Invocation and Triggers (Conditional) ---
#

# Grants public, unauthenticated access to the Cloud Run service.
resource "google_cloud_run_service_iam_member" "public_access" {
  # This IAM binding is created only if 'allow_unauthenticated' is true.
  for_each = var.allow_unauthenticated ? { this = true } : {}

  # The GCP project ID of the service.
  project = google_cloud_run_v2_service.agent_engine.project
  # The location of the service.
  location = google_cloud_run_v2_service.agent_engine.location
  # The name of the service.
  service = google_cloud_run_v2_service.agent_engine.name
  # The invoker role allows calling the service.
  role = "roles/run.invoker"
  # 'allUsers' is a special member representing anyone on the internet.
  member = "allUsers"
}

# An Eventarc trigger to invoke the agent based on GCS events.
resource "google_eventarc_trigger" "gcs_trigger" {
  # This resource is created only if 'eventarc_trigger_gcs' is configured.
  for_each = var.eventarc_trigger_gcs != null ? { this = true } : {}

  # The GCP project ID for the trigger.
  project = local.project_id
  # A unique name for the Eventarc trigger.
  name = "${var.name}-gcs-trigger"
  # The region where the trigger will be created.
  location = var.location

  # Criteria to match events from Cloud Storage.
  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }
  matching_criteria {
    attribute = "bucket"
    value     = var.eventarc_trigger_gcs.bucket
  }

  # The destination to send the event to, which is our Cloud Run service.
  destination {
    cloud_run_service {
      service = google_cloud_run_v2_service.agent_engine.name
      region  = var.location
    }
  }

  # The service account that Eventarc uses to invoke the destination.
  service_account = "service-${data.google_project.project.number}@gcp-sa-eventarc.iam.gserviceaccount.com"
}

# Grants the Eventarc service account permission to invoke the Cloud Run service.
resource "google_cloud_run_service_iam_member" "eventarc_invoker" {
  # This IAM binding is created only if 'eventarc_trigger_gcs' is configured.
  for_each = var.eventarc_trigger_gcs != null ? { this = true } : {}

  # The GCP project ID of the service.
  project = google_cloud_run_v2_service.agent_engine.project
  # The location of the service.
  location = google_cloud_run_v2_service.agent_engine.location
  # The name of the service.
  service = google_cloud_run_v2_service.agent_engine.name
  # The invoker role allows calling the service.
  role = "roles/run.invoker"
  # The default service account used by Eventarc.
  member = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-eventarc.iam.gserviceaccount.com"
}

# A Cloud Scheduler job to invoke the agent on a cron schedule.
resource "google_cloud_scheduler_job" "agent_cron_trigger" {
  # This resource is created only if 'scheduler_job' is configured.
  for_each = var.scheduler_job != null ? { this = true } : {}

  # The GCP project ID for the scheduler job.
  project = local.project_id
  # A unique name for the scheduler job.
  name = "${var.name}-cron-trigger"
  # The region where the job will be created.
  region = var.location
  # The schedule in cron format.
  schedule = var.scheduler_job.schedule
  # The time zone for the schedule.
  time_zone = var.scheduler_job.time_zone

  # The HTTP target to invoke.
  http_target {
    # The URI of the Cloud Run service.
    uri = google_cloud_run_v2_service.agent_engine.uri
    # The HTTP method to use for the request.
    http_method = var.scheduler_job.http_method
    # The request body, if any.
    body = var.scheduler_job.body != null ? base64encode(var.scheduler_job.body) : null
    # Use an OIDC token to securely authenticate with the Cloud Run service.
    oidc_token {
      service_account_email = local.agent_service_account_email
    }
  }
}

# Grants the agent's service account permission to invoke the Cloud Run service.
# This is required for Cloud Scheduler jobs using OIDC tokens for authorization.
resource "google_cloud_run_service_iam_member" "scheduler_invoker" {
  # This resource is created only if 'scheduler_job' is configured.
  for_each = var.scheduler_job != null ? { this = true } : {}

  # The GCP project ID for the service.
  project = google_cloud_run_v2_service.agent_engine.project
  # The location of the service.
  location = google_cloud_run_v2_service.agent_engine.location
  # The name of the service.
  service = google_cloud_run_v2_service.agent_engine.name
  # The invoker role allows calling the service.
  role = "roles/run.invoker"
  # The service account used by the scheduler job to generate an OIDC token.
  member = "serviceAccount:${local.agent_service_account_email}"
}
