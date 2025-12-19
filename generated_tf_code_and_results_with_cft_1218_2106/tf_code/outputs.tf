# <!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
# <!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
output "cloud_run_service_id" {
  description = "The fully qualified ID of the created Cloud Run service."
  value       = google_cloud_run_v2_service.agent_engine_service.id
}

output "cloud_run_service_uri" {
  description = "The publicly invokable URI of the Agent Engine's Cloud Run service."
  value       = google_cloud_run_v2_service.agent_engine_service.uri
}

output "pubsub_topic_id" {
  description = "The fully qualified ID of the Pub/Sub topic used as the task queue for the Agent Engine."
  value       = google_pubsub_topic.agent_tasks.id
}

output "service_account_email" {
  description = "The email address of the service account used by the Agent Engine."
  value       = local.agent_sa_email
}
