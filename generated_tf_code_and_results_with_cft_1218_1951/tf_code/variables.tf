variable "allow_unauthenticated" {
  description = "If set to true, the Cloud Run service will be publicly accessible to all users."
  type        = bool
  default     = false
}

variable "container_env_vars" {
  description = "A map of environment variables to be passed to the container."
  type        = map(string)
  default     = {}
}

variable "container_image" {
  description = "The URI of the container image to be deployed for the agent (e.g., 'gcr.io/my-project/my-agent:latest')."
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}

variable "container_port" {
  description = "The port number that the container listens on."
  type        = number
  default     = 8080
}

variable "enable_redis" {
  description = "If set to true, a Memorystore (Redis) instance will be created and connected to the agent via a Serverless VPC Access Connector."
  type        = bool
  default     = false
}

variable "eventarc_trigger_gcs" {
  description = "If configured, creates an Eventarc trigger that invokes the agent when a new object is created in the specified GCS bucket. Provide an object with a 'bucket' attribute."
  type = object({
    bucket = string
  })
  default = null
}

variable "location" {
  description = "The Google Cloud region where the resources will be created (e.g., 'us-central1')."
  type        = string
  default     = "us-central1"
}

variable "name" {
  description = "A unique name for the agent engine. This will be used as a prefix for all created resources."
  type        = string
  default     = "agent-engine"
}

variable "network_config" {
  description = "Network configuration. Required if 'enable_redis' is true. 'network_name' is the name of the VPC network, not the full resource ID."
  type = object({
    network_name         = string
    connector_cidr_range = optional(string, "10.8.0.0/28")
  })
  default = null
}

variable "project_id" {
  description = "The ID of the Google Cloud project where the resources will be created. If not provided, the provider project is used."
  type        = string
  default     = null
}

variable "redis_config" {
  description = "Configuration for the Memorystore (Redis) instance. Only used if 'enable_redis' is true."
  type = object({
    tier           = optional(string, "BASIC")
    memory_size_gb = optional(number, 1)
  })
  default = {
    tier           = "BASIC"
    memory_size_gb = 1
  }
}

variable "scaling" {
  description = "Configuration for the Cloud Run service's autoscaling settings."
  type = object({
    min_instance_count = optional(number, 0)
    max_instance_count = optional(number, 10)
  })
  default = {
    min_instance_count = 0
    max_instance_count = 10
  }
}

variable "scheduler_job" {
  description = "If configured, creates a Cloud Scheduler job to invoke the agent on a specified schedule. The job will securely call the agent using an OIDC token."
  type = object({
    schedule    = string
    time_zone   = optional(string, "Etc/UTC")
    http_method = optional(string, "POST")
    body        = optional(string)
  })
  default = null
}

variable "service_account_create" {
  description = "A boolean flag to control the creation of a new service account for the agent. If false, 'service_account_email' must be provided."
  type        = bool
  default     = true
}

variable "service_account_email" {
  description = "The email of an existing service account to use for the agent. Required if 'service_account_create' is false."
  type        = string
  default     = null
}

variable "service_account_roles" {
  description = "A list of project-level IAM roles to grant to the agent's service account (e.g., ['roles/storage.objectViewer']). Warning: Granting project-level roles can have broad security implications. Prefer more granular, resource-specific roles where possible."
  type        = list(string)
  default     = []
}
