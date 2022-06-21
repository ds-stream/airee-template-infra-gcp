terraform {
  backend "gcs" {
    bucket = "{{cookiecutter.tf_backend}}"
    prefix = "terraform-{{cookiecutter.workspace}}/state/dev/"
  }
}