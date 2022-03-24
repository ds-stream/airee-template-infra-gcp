# Can we somehow make global variables? Not supported by Hashicorp
variable "project_id" {
  default = "dsstream-airflowk8s"
}
variable "region" {
  default = "asia-northeast1"
}
variable "gcs_tf_backend_name" {
  default = "tf_airkube_backend"
}