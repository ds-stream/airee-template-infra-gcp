# https://www.terraform.io/language/settings/backends/gcs
terraform {
  backend "gcs" {
    bucket = "{{cookiecutter.tf_backend}}"
    prefix = "terraform-{{cookiecutter.workspace}}/state/{{cookiecutter.cert_name}}/"
  }
}