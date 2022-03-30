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
  default = "{{cookiecutter.zone}}"
}
#################################################
variable "private_network_name" {
  default = "{{cookiecutter.network_name}}"
}
#################################################
variable "database_instance_name" {
  default = "{{cookiecutter.database_instance_name}}"
}
variable "database_instance_version" {
  default = "POSTGRES_13"
}
variable "postgres_database_name" {
  default = "airflow_db"
}
#################################################
variable "additional_nodepool" {
  type = map(any)
  default = {
    name         = "additional"
    node_count   = 1
    machine_type = "custom-4-3840"
  }
}
variable "webserver_nodepool" {
  type = map(any)
  default = {
    name         = "webserver"
    node_count   = 1
    machine_type = "custom-4-3840"
  }
}
variable "worker_nodepool" {
  type = map(any)
  default = {
    name         = "worker"
    node_count   = 1
    machine_type = "custom-4-6144"
  }
}
variable "scheduler_nodepool" {
  type = map(any)
  default = {
    name         = "scheduler"
    node_count   = 1
    machine_type = "e2-medium"
  }
}
#################################################
variable "cluster_name" {
  default = "{{cookiecutter.cluster_name}}"
}
variable "namespace" {
  default = "airflow"
}