output "GKE_context" {
  description = "The first public IPv4 address assigned for the PostgreSQL instance."
  value       = "gcloud container clusters get-credentials ${var.cluster_name} --region ${var.region} --project ${var.project_id}"

}