# <!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
variable "agent_container_image" {
  description = "The container image to be used for the Agent Engine's Cloud Run service."
  type        = string
  default     = "gcr.io/cloudrun/hello"
}

variable "cloud_run_service_params" {
  description = "Configuration parameters for the Cloud Run service, including scaling, concurrency, and environment variables."
  type = object({
    max_scale                        = optional(number, 10)
    min_scale                        = optional(number, 0)
    max_instance_request_concurrency = optional(number, 80)
    timeout_seconds                  = optional(number, 300)
    available_memory                 = optional(string, "512Mi")
    env = optional(list(object({
      name  = string
      value = string
    })), [])
    secrets = optional(map(object({
      secret  = string
      version = string
    })), {})
  })
  default = {}
}

variable "grant_eventarc_sa_user_role" {
  description = "If true, grants the Eventarc service account the 'Service Account User' role on the agent's service account, which is required for Eventarc to impersonate the service account to invoke the Cloud Run service."
  type        = bool
  default     = true
}

variable "grant_pubsub_token_creator_role" {
  description = "If true, grants the Pub/Sub service account the 'Service Account Token Creator' role on the agent's service account, which is required for Eventarc to invoke Cloud Run with authentication."
  type        = bool
  default     = true
}

variable "location" {
  description = "The GCP region to deploy the Agent Engine resources into."
  type        = string
  default     = "us-central1"
}

variable "name" {
  description = "The base name for all resources created by this module."
  type        = string
  default     = "agent-engine"
}

variable "project_id" {
  description = "The GCP project ID where the Agent Engine and its resources will be deployed. If not provided, the provider project is used."
  type        = string
  default     = null
}

variable "service_account_create" {
  description = "A boolean flag to control the creation of a new service account for the Agent Engine. If false, `service_account_email` must be provided."
  type        = bool
  default     = true
}

variable "service_account_email" {
  description = "The email of an existing service account to be used by the Agent Engine. Required if `service_account_create` is false."
  type        = string
  default     = null
}
