terraform {
  required_version = ">= 1.3.4"
}
provider "google" {
  project = var.project_id
  region  = var.region
}