<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
# Terraform Google Cloud Agent Engine Module

This Terraform module is used to provision a generic, container-based agent engine on Google Cloud Platform. It uses Cloud Run as the core serverless compute and provides flexible options for invocation, state management, and networking. The module can be configured to create agents for various use cases, including:

-   Event-driven processing (e.g., triggered by Cloud Storage events via Eventarc).
-   Scheduled tasks (e.g., cron jobs via Cloud Scheduler).
-   Publicly accessible web services or APIs.
-   Stateful services connected to a private Memorystore (Redis) instance.

The module handles the creation of a dedicated service account, networking components like VPC Access Connectors, and the necessary IAM bindings to connect all components securely.

## Usage

### Basic Usage

This example deploys a minimal private agent engine using a specified container image.

```hcl
module "agent_engine" {
  source = "./" // Or your module source

  name            = "my-processing-agent"
  project_id      = "my-gcp-project-id"
  location        = "us-central1"
  container_image = "gcr.io/my-gcp-project-id/my-agent-image:latest"

  service_account_roles = [
    "roles/storage.objectViewer",
    "roles/logging.logWriter"
  ]
}
```

### Publicly Accessible Web Service

This example configures the agent to be a publicly accessible web service by allowing unauthenticated invocations.

```hcl
module "public_api_agent" {
  source = "./"

  name                  = "my-public-api"
  project_id            = "my-gcp-project-id"
  location              = "us-central1"
  container_image       = "gcr.io/my-gcp-project-id/my-api-image:latest"
  allow_unauthenticated = true
}
```

### Stateful Agent with Redis

This example provisions a stateful agent connected to a Memorystore for Redis instance for caching or state management. This requires VPC networking configuration.

```hcl
module "stateful_agent" {
  source = "./"

  name            = "my-stateful-agent"
  project_id      = "my-gcp-project-id"
  location        = "us-central1"
  container_image = "gcr.io/my-gcp-project-id/my-stateful-agent:latest"

  enable_redis = true
  network_config = {
    network_name         = "my-vpc-network"
    connector_cidr_range = "10.8.0.0/28"
  }
  redis_config = {
    tier           = "BASIC"
    memory_size_gb = 1
  }
}
```

### Event-Driven Agent (GCS Trigger)

This example configures the agent to be invoked by Eventarc whenever a new object is created in a specific Cloud Storage bucket.

```hcl
module "gcs_processing_agent" {
  source = "./"

  name            = "my-gcs-processor"
  project_id      = "my-gcp-project-id"
  location        = "us-central1"
  container_image = "gcr.io/my-gcp-project-id/my-gcs-processor:latest"

  eventarc_trigger_gcs = {
    bucket = "my-input-bucket-name"
  }
}
```

### Scheduled Agent (Cron Job)

This example configures a Cloud Scheduler job to invoke the agent on a cron schedule.

```hcl
module "daily_report_agent" {
  source = "./"

  name            = "my-daily-reporter"
  project_id      = "my-gcp-project-id"
  location        = "us-central1"
  container_image = "gcr.io/my-gcp-project-id/my-reporting-agent:latest"

  scheduler_job = {
    schedule    = "0 5 * * *" # Every day at 5 AM
    time_zone   = "America/New_York"
    http_method = "POST"
    body        = "{\"report_type\":\"daily_summary\"}"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_google"></a> [google](#requirement\_google) | ~> 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allow_unauthenticated"></a> [allow\_unauthenticated](#input\_allow\_unauthenticated) | If set to true, the Cloud Run service will be publicly accessible to all users. | `bool` | `false` | no |
| <a name="input_container_env_vars"></a> [container\_env\_vars](#input\_container\_env\_vars) | A map of environment variables to be passed to the container. | `map(string)` | `{}` | no |
| <a name="input_container_image"></a> [container\_image](#input\_container\_image) | The URI of the container image to be deployed for the agent (e.g., 'gcr.io/my-project/my-agent:latest'). | `string` | `"us-docker.pkg.dev/cloudrun/container/hello"` | no |
| <a name="input_container_port"></a> [container\_port](#input\_container\_port) | The port number that the container listens on. | `number` | `8080` | no |
| <a name="input_enable_redis"></a> [enable\_redis](#input\_enable\_redis) | If set to true, a Memorystore (Redis) instance will be created and connected to the agent via a Serverless VPC Access Connector. | `bool` | `false` | no |
| <a name="input_eventarc_trigger_gcs"></a> [eventarc\_trigger\_gcs](#input\_eventarc\_trigger\_gcs) | If configured, creates an Eventarc trigger that invokes the agent when a new object is created in the specified GCS bucket. Provide an object with a 'bucket' attribute. | <pre>object({<br>    bucket = string<br>  })</pre> | `null` | no |
| <a name="input_location"></a> [location](#input\_location) | The Google Cloud region where the resources will be created (e.g., 'us-central1'). | `string` | `"us-central1"` | no |
| <a name="input_name"></a> [name](#input\_name) | A unique name for the agent engine. This will be used as a prefix for all created resources. | `string` | `"agent-engine"` | no |
| <a name="input_network_config"></a> [network\_config](#input\_network\_config) | Network configuration. Required if 'enable\_redis' is true. 'network\_name' is the name of the VPC network, not the full resource ID. | <pre>object({<br>    network_name         = string<br>    connector_cidr_range = optional(string, "10.8.0.0/28")<br>  })</pre> | `null` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | The ID of the Google Cloud project where the resources will be created. If not provided, the provider project is used. | `string` | `null` | no |
| <a name="input_redis_config"></a> [redis\_config](#input\_redis\_config) | Configuration for the Memorystore (Redis) instance. Only used if 'enable\_redis' is true. | <pre>object({<br>    tier           = optional(string, "BASIC")<br>    memory_size_gb = optional(number, 1)<br>  })</pre> | <pre>{<br>  "memory_size_gb": 1,<br>  "tier": "BASIC"<br>}</pre> | no |
| <a name="input_scaling"></a> [scaling](#input\_scaling) | Configuration for the Cloud Run service's autoscaling settings. | <pre>object({<br>    min_instance_count = optional(number, 0)<br>    max_instance_count = optional(number, 10)<br>  })</pre> | <pre>{<br>  "max_instance_count": 10,<br>  "min_instance_count": 0<br>}</pre> | no |
| <a name="input_scheduler_job"></a> [scheduler\_job](#input\_scheduler\_job) | If configured, creates a Cloud Scheduler job to invoke the agent on a specified schedule. The job will securely call the agent using an OIDC token. | <pre>object({<br>    schedule    = string<br>    time_zone   = optional(string, "Etc/UTC")<br>    http_method = optional(string, "POST")<br>    body        = optional(string)<br>  })</pre> | `null` | no |
| <a name="input_service_account_create"></a> [service\_account\_create](#input\_service\_account\_create) | A boolean flag to control the creation of a new service account for the agent. If false, 'service\_account\_email' must be provided. | `bool` | `true` | no |
| <a name="input_service_account_email"></a> [service\_account\_email](#input\_service\_account\_email) | The email of an existing service account to use for the agent. Required if 'service\_account\_create' is false. | `string` | `null` | no |
| <a name="input_service_account_roles"></a> [service\_account\_roles](#input\_service\_account\_roles) | A list of project-level IAM roles to grant to the agent's service account (e.g., ['roles/storage.objectViewer']). Warning: Granting project-level roles can have broad security implications. Prefer more granular, resource-specific roles where possible. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloud_run_service_id"></a> [cloud\_run\_service\_id](#output\_cloud\_run\_service\_id) | The fully qualified ID of the created Cloud Run service. |
| <a name="output_cloud_run_service_uri"></a> [cloud\_run\_service\_uri](#output\_cloud\_run\_service\_uri) | The publicly invokable URI of the Cloud Run service. |
| <a name="output_redis_instance_host"></a> [redis\_instance\_host](#output\_redis\_instance\_host) | The IP address or hostname of the Redis instance. This output is only available if 'enable\_redis' is true. |
| <a name="output_redis_instance_id"></a> [redis\_instance\_id](#output\_redis\_instance\_id) | The ID of the Memorystore Redis instance. This output is only available if 'enable\_redis' is true. |
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | The email of the service account used by the Agent Engine. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
