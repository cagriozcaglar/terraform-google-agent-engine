# Terraform Google Cloud Agent Engine Module

This module deploys a serverless, event-driven "Agent Engine" on Google Cloud Platform. It provisions a core set of resources including:
*   A Cloud Run service to run the agent's container image.
*   A Pub/Sub topic to act as a task queue.
*   An Eventarc trigger to connect the Pub/Sub topic to the Cloud Run service, invoking it on new messages.
*   A dedicated IAM Service Account with the necessary permissions for secure operation.

This architecture provides a scalable, cost-effective, and decoupled system for processing asynchronous tasks.

## Usage

Basic usage of this module is as follows:

```hcl
module "agent_engine" {
  source                = "PATH_TO_MODULE" # e.g., git::https://github.com/your-org/your-repo.git//path/to/module
  project_id            = "your-gcp-project-id"
  name                  = "my-awesome-agent"
  location              = "us-central1"
  agent_container_image = "gcr.io/my-project/my-agent:latest"

  cloud_run_service_params = {
    max_scale        = 5
    available_memory = "1Gi"
    env = [
      {
        name  = "LOG_LEVEL"
        value = "INFO"
      }
    ]
  }
}
```

## Compatibility

This module is meant for use with Terraform `1.3.0` and later.

## Requirements

### Terraform Plugins
- [Terraform](https://www.terraform.io/downloads.html) >= 1.3.0
- [Google Provider](https://github.com/hashicorp/terraform-provider-google) ~> 5.14

### APIs

A project with the following APIs enabled is required:
- Cloud Run API: `run.googleapis.com`
- Pub/Sub API: `pubsub.googleapis.com`
- Eventarc API: `eventarc.googleapis.com`
- IAM API: `iam.googleapis.com`
- Cloud Resource Manager API: `cloudresourcemanager.googleapis.com`
- Secret Manager API: `secretmanager.googleapis.com`

The Service Usage API (`serviceusage.googleapis.com`) is also required to enable these APIs.

### Permissions

The user or service account executing this module requires the following permissions on the project:
- `roles/run.admin`
- `roles/pubsub.editor`
- `roles/eventarc.admin`
- `roles/iam.serviceAccountAdmin`
- `roles/resourcemanager.projectIamAdmin` (or the ability to grant IAM roles on service accounts)
- `roles/serviceusage.serviceUsageAdmin` (to enable APIs)

This module will grant the following roles to Google-managed service accounts:
- `roles/iam.serviceAccountUser` to the Eventarc Service Agent.
- `roles/iam.serviceAccountTokenCreator` to the Pub/Sub Service Agent.

## Inputs

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| agent\_container\_image | The container image to be used for the Agent Engine's Cloud Run service. | `string` | `"gcr.io/cloudrun/hello"` | no |
| cloud\_run\_service\_params | Configuration parameters for the Cloud Run service, including scaling, concurrency, and environment variables. | <pre>object({<br>    max_scale                        = optional(number, 10)<br>    min_scale                        = optional(number, 0)<br>    max_instance_request_concurrency = optional(number, 80)<br>    timeout_seconds                  = optional(number, 300)<br>    available_memory                 = optional(string, "512Mi")<br>    env = optional(list(object({<br>      name  = string<br>      value = string<br>    })), [])<br>    secrets = optional(map(object({<br>      secret  = string<br>      version = string<br>    })), {})<br>  })</pre> | `{}` | no |
| grant\_eventarc\_sa\_user\_role | If true, grants the Eventarc service account the 'Service Account User' role on the agent's service account, which is required for Eventarc to impersonate the service account to invoke the Cloud Run service. | `bool` | `true` | no |
| grant\_pubsub\_token\_creator\_role | If true, grants the Pub/Sub service account the 'Service Account Token Creator' role on the agent's service account, which is required for Eventarc to invoke Cloud Run with authentication. | `bool` | `true` | no |
| location | The GCP region to deploy the Agent Engine resources into. | `string` | `"us-central1"` | no |
| name | The base name for all resources created by this module. | `string` | `"agent-engine"` | no |
| project\_id | The GCP project ID where the Agent Engine and its resources will be deployed. If not provided, the provider project is used. | `string` | `null` | no |
| service\_account\_create | A boolean flag to control the creation of a new service account for the Agent Engine. If false, `service_account_email` must be provided. | `bool` | `true` | no |
| service\_account\_email | The email of an existing service account to be used by the Agent Engine. Required if `service_account_create` is false. | `string` | `null` | no |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Outputs

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
| Name | Description |
|------|-------------|
| cloud\_run\_service\_id | The fully qualified ID of the created Cloud Run service. |
| cloud\_run\_service\_uri | The publicly invokable URI of the Agent Engine's Cloud Run service. |
| pubsub\_topic\_id | The fully qualified ID of the Pub/Sub topic used as the task queue for the Agent Engine. |
| service\_account\_email | The email address of the service account used by the Agent Engine. |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Contributing

Refer to the `CONTRIBUTING.md` file for instructions on how to contribute to this module.

## License

Copyright 2023 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUTHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
