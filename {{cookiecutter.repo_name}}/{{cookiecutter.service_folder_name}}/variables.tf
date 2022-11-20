#############   GCP PPROJECT   ################
variable "project_id" {
  default = "{{cookiecutter.project_id}}"
}
variable "region" {
  default = "{{cookiecutter.region}}"
}
variable "zone" {
  default = "{{cookiecutter.zone}}"
}

################   VPC   ######################
variable "private_network_name" {
  default = "{{cookiecutter.network_name}}-{{cookiecutter.workspace}}-{{cookiecutter.env}}"
}
variable "private-ip-address_name" {
  default = "private-ip-address-{{cookiecutter.workspace}}-{{cookiecutter.env}}"
}

###############  DOMAIN  #####################

variable "dns_zone_name" {
  default = "{{cookiecutter.dns_zone}}"
}
variable "subdomain_name" {
  default = "{{cookiecutter.workspace}}-{{cookiecutter.env}}"
}
variable "domain_name" {
  default = "{{cookiecutter.domain}}"
}

###########   POSTGRES SQL   ##################
variable "database_instance_name" {
  default = "{{cookiecutter.database_instance_name}}-{{cookiecutter.workspace}}-{{cookiecutter.env}}"
}
variable "database_instance_version" {
  default = "POSTGRES_14"
}
variable "postgres_database_name" {
  default = "airflow_db"
}
variable "postgres_user_name" {
  default = "airflow"
}
variable "postgres_user_password" {
  default = "airflow"
}

###########   WORDLOAD $ SA   #################

variable "workload_identity_user" {
  default = "wi-usr-{{cookiecutter.workspace}}-{{cookiecutter.env}}"
}

###########   GKE CLUSTER   ###################

variable "webserver_nodepool" {
  type = map(any)
  default = {
    name         = "webserver"
    node_count   = 1
    machine_type = "custom-4-8192"
  }
}
variable "worker_nodepool" {
  type = map(any)
  default = {
    name         = "worker"
    taint        = "worker"
    {% if cookiecutter.airflow_performance == 'small' -%}
    node_count   = 1
    machine_type = "custom-4-8192"
    {% elif cookiecutter.airflow_performance == 'standard' -%}
    node_count   = 2
    machine_type = "custom-4-8192"
    {% elif cookiecutter.airflow_performance == 'large' -%}
    node_count   = 4
    machine_type = "custom-4-8192"
    {%- endif %}
  }
}
variable "cluster_name" {
  default = "{{cookiecutter.cluster_name}}-{{cookiecutter.workspace}}-{{cookiecutter.env}}"
}
variable "namespace" {
  default = "{{cookiecutter._namespace}}"
}

###########   NFS DISK   ###################
variable "nfs_disk" {
  type = map(any)
  default = {
    name  = "nfs-disk-{{cookiecutter.workspace}}-{{cookiecutter.env}}"
    type  = "pd-standard"
    size  = 10    
  }
}

############   FLUX   ########################
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
