terraform {
  required_version = ">= 1.1.5"
}
provider "google" {
  project     = var.project_id
  region      = var.region
}