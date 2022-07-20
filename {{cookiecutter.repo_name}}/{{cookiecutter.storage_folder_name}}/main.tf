# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket
# Run once to create storage for terraform remote state backend
 
resource "google_storage_bucket" "tf_remote_backend" {
  name = var.gcs_tf_backend_name
  project = var.project_id
  location = var.region
  force_destroy = true

  versioning {
    enabled = true
  }
}