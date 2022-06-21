# Can we somehow make global variables? Not supported by Hashicorp
variable "project_id" {
  default = "{{cookiecutter.project_id}}"
}
variable "region" {
  default = "asia-northeast1"
}
variable "gcs_tf_backend_name" {
  default = "tf_airkube_backend"
}