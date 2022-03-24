##########################################################################################
#  ___ _   _ _____ ____      _    ____ _____ ____  _   _  ____ _____ _   _ ____  _____   #
# |_ _| \ | |  ___|  _ \    / \  / ___|_   _|  _ \| | | |/ ___|_   _| | | |  _ \| ____|  #
#  | ||  \| | |_  | |_) |  / _ \ \___ \ | | | |_) | | | | |     | | | | | | |_) |  _|    #
#  | || |\  |  _| |  _ <  / ___ \ ___) || | |  _ <| |_| | |___  | | | |_| |  _ <| |___   #
# |___|_| \_|_|   |_| \_\/_/   \_\____/ |_| |_| \_\\___/ \____| |_|  \___/|_| \_\_____|  #
##########################################################################################              

variable "project_id" {
  default = "{{cookiecutter.project_id}}"
}
variable "region" {
  default = "{{cookiecutter.region}}"
}
variable "zone" {
  default     = "{{cookiecutter.zone}}"
}
#################################################
variable "private_network_name" {
  default     = "{{cookiecutter.network_name}}"
}
#################################################
variable "database_instance_name" {
  default     = "{{cookiecutter.database_instance_name}}"
}
variable "database_instance_version" {
  default     = "POSTGRES_13"
}
variable "postgres_database_name" {
  default     = "airflow_db"
}
#################################################
variable "nodepool_name" {
  default     = "my-node-pool"
}
variable "cluster_name" {
  default     = "{{cookiecutter.cluster_name}}"
}
variable "namespace" {
  default     = "airflow"
}