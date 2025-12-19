output "cloud_run_service_id" {
  description = "The fully qualified ID of the created Cloud Run service."
  value       = google_cloud_run_v2_service.agent_engine.id
}

output "cloud_run_service_uri" {
  description = "The publicly invokable URI of the Cloud Run service."
  value       = google_cloud_run_v2_service.agent_engine.uri
}

output "redis_instance_host" {
  description = "The IP address or hostname of the Redis instance. This output is only available if 'enable_redis' is true."
  value       = var.enable_redis ? one(google_redis_instance.agent_cache).host : null
}

output "redis_instance_id" {
  description = "The ID of the Memorystore Redis instance. This output is only available if 'enable_redis' is true."
  value       = var.enable_redis ? one(google_redis_instance.agent_cache).id : null
}

output "service_account_email" {
  description = "The email of the service account used by the Agent Engine."
  value       = local.agent_service_account_email
}
