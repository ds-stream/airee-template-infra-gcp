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
  default = "{{cookiecutter.network_name}}-{{cookiecutter.workspace}}"
}
variable "private-ip-address_name" {
  default = "private-ip-address-{{cookiecutter.workspace}}"
}

#################################################
variable "database_instance_name" {
  default = "{{cookiecutter.database_instance_name}}-{{cookiecutter.workspace}}"
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
    name         = "{{cookiecutter._nodeSelectorPurposeAdditional}}"
    {% if cookiecutter.airflow_performance == 'small' -%}
    node_count   = 0
    {% elif cookiecutter.airflow_performance == 'standard' -%}
    node_count   = 0
    {% elif cookiecutter.airflow_performance == 'large' -%}
    node_count   = 1
    {%- endif %}
    
    machine_type = "custom-4-4096"
  }
}
variable "webserver_nodepool" {
  type = map(any)
  default = {
    name         = "{{cookiecutter._nodeSelectorPurposeWebserver}}"
    node_count   = 1
    {% if cookiecutter.airflow_performance == 'small' -%}
    machine_type = "custom-4-5120"
    {% elif cookiecutter.airflow_performance == 'standard' -%}
    machine_type = "custom-4-6144"
    {% elif cookiecutter.airflow_performance == 'large' -%}
    machine_type = "custom-2-4096"
    taint        = "{{cookiecutter._nodeSelectorPurposeWebserver}}"
    {%- endif %}
  }
}
variable "worker_nodepool" {
  type = map(any)
  default = {
    name         = "{{cookiecutter._nodeSelectorPurposeWorker}}"
    taint        = "{{cookiecutter._nodeSelectorPurposeWorker}}"
    {% if cookiecutter.airflow_performance == 'small' -%}
    node_count   = 1
    machine_type = "custom-4-12288"
    {% elif cookiecutter.airflow_performance == 'standard' -%}
    node_count   = 1
    machine_type = "custom-6-12288"
    {% elif cookiecutter.airflow_performance == 'large' -%}
    node_count   = 1
    machine_type = "custom-6-12288"
    {%- endif %}
  }
}
variable "scheduler_nodepool" {
  type = map(any)
  default = {
    name         = "{{cookiecutter._nodeSelectorPurposeScheduler}}"
    {% if cookiecutter.airflow_performance == 'small' -%}
    node_count   = 0
    machine_type = "e2-medium"
    {% elif cookiecutter.airflow_performance == 'standard' -%}
    node_count   = 0
    machine_type = "custom-2-4096"
    {% elif cookiecutter.airflow_performance == 'large' -%}
    node_count   = 1
    machine_type = "custom-2-4096"
    taint        = "{{cookiecutter._nodeSelectorPurposeScheduler}}"
    {%- endif %}
    
  }
}
#################################################
variable "cluster_name" {
  default = "{{cookiecutter.cluster_name}}-{{cookiecutter.workspace}}"
}
variable "namespace" {
  default = "airflow"
}
#################################################
variable "nfs_disk" {
  type = map(any)
  default = {
    name  = "nfs-disk-{{cookiecutter.workspace}}"
    type  = "pd-standard"
    size  = 10
    
    
  }
}
##### FLUX

# put as a os env 
# export TF_VAR_github_token=<token>
variable "github_token" {
  description = "token for github"
  type        = string
}

variable "repository_name" {
  description = "repository name"
  type        = string
  # Add to cookiecutter
  default = "{{cookiecutter.workspace}}_app_{{cookiecutter.env}}"
}

variable "organization" {
  description = "organization"
  type        = string
  default = "{{cookiecutter.org}}"
}

variable "branch" {
  description = "branch"
  type        = string
  default     = "main"
}

variable "target_path" {
  type        = string
  description = "Relative path to the Git repository root where the sync manifests are committed."
  default = "flux/"
}

variable "flux_namespace" {
  type        = string
  default     = "flux-system"
  description = "the flux namespace"
}

variable "github_deploy_key_title" {
  type        = string
  description = "Name of github deploy key"
  default = "flux_key"
}