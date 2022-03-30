terraform {
  backend "gcs" {
    bucket = "tf_airkube_backend"
    prefix = "terraform/state/dev/"
  }
}