# TODO Add Kubernetes provider
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/guides/getting-started#provider-setup
# add namespace and configmap


#############
#### VPC ####
#############

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network
# Create virtual network for whole infrastructure
resource "google_compute_network" "private_network" {
  provider = google-beta
  project  = var.project_id
  name     = var.private_network_name
  auto_create_subnetworks = false
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_subnetwork
# Create subnetwork for infrastructure
resource "google_compute_subnetwork" "subnetwork" {
  name          = "${var.private_network_name}-subnetwork"
  ip_cidr_range = "10.2.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.private_network.id
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address
# Global addresses are used for HTTP(S) load balancing.
resource "google_compute_global_address" "private_ip_address" {
  provider      = google-beta
  project       = var.project_id
  name          = var.private-ip-address_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.private_network.id
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection
# Manages a private VPC connection with a GCP service provider.
resource "google_service_networking_connection" "private_vpc_connection" {
  provider = google-beta

  network                 = google_compute_network.private_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}


######################
#### POSTGRES SQL ####
######################

# Sufix for postgres database name
resource "random_id" "db_name_suffix" {
  byte_length = 4
}


# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance
# Create PostgreSQL Database
resource "google_sql_database_instance" "instance" {
  provider         = google-beta
  project          = var.project_id
  name             = "${var.database_instance_name}-${random_id.db_name_suffix.hex}"
  region           = var.region
  database_version = var.database_instance_version

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = "db-g1-small"
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.private_network.id
    }
  }
  deletion_protection = false
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user
# Create SQL user for Airflow 
resource "google_sql_user" "users" {
  name       = "airflow"
  instance   = google_sql_database_instance.instance.name
  password   = "airflow"
  depends_on = [google_sql_database_instance.instance]

}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database
# Create Database for Airflow metadata
resource "google_sql_database" "database" {
  name       = var.postgres_database_name
  instance   = google_sql_database_instance.instance.name
  depends_on = [google_sql_database_instance.instance]
}


#################
#### CLUSTER ####
#################

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster
# Create GKE Cluester
resource "google_container_cluster" "primary" {
  name                     = var.cluster_name
  location                 = var.region
  remove_default_node_pool = true
  initial_node_count       = 1
  networking_mode          = "VPC_NATIVE"
  network                  = google_compute_network.private_network.name
  subnetwork               = google_compute_subnetwork.subnetwork.name 
  ip_allocation_policy {}
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  depends_on = [google_service_networking_connection.private_vpc_connection, google_compute_disk.nfs-disk]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool
# Create kubernetes nodepool for webserver and workers
resource "google_container_node_pool" "webserver_nodepool" {
  name           = var.webserver_nodepool["name"]
  location       = var.region
  cluster        = google_container_cluster.primary.name
  node_count     = var.webserver_nodepool["node_count"]
  node_locations = [var.zone]
  node_config {
    preemptible  = true
    machine_type = var.webserver_nodepool["machine_type"]
    labels       = { "purpose" = var.webserver_nodepool["name"] }
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  depends_on = [google_container_cluster.primary]
}

resource "google_container_node_pool" "worker_nodepool" {
  name           = var.worker_nodepool["name"]
  location       = var.region
  cluster        = google_container_cluster.primary.name
  node_count     = var.worker_nodepool["node_count"]
  node_locations = [var.zone]
  node_config {
    preemptible  = true
    machine_type = var.worker_nodepool["machine_type"]
    labels       = { "purpose" = var.worker_nodepool["name"] }
    taint {
      key    = "purpose"
      value  = "worker"
      effect = "NO_SCHEDULE"
    }
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  depends_on = [google_container_cluster.primary]
}


#############
#### NFS ####
#############
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_disk
# Create NFS Disk for Airflow logs
resource "google_compute_disk" "nfs-disk" {
  name                      = var.nfs_disk["name"]
  type                      = var.nfs_disk["type"]
  zone                      = var.zone
  size                      = var.nfs_disk["size"]
  physical_block_size_bytes = 4096
}


#############
#### DNS ####
#############

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_address
# Reserve static IP
resource "google_compute_address" "static" {
  name       = var.cluster_name
  region     = var.region
  depends_on = [google_container_node_pool.webserver_nodepool]
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set
# Add record to DNS if it exist
{% if cookiecutter.domain!=None %}
resource "google_dns_record_set" "type_a" {
  name         = "${var.subdomain_name}.${var.domain_name}."
  managed_zone = var.dns_zone_name
  type         = "A"
  ttl          = 300

  rrdatas    = ["${google_compute_address.static.address}"]
  depends_on = [google_compute_address.static]
}
{% endif %}

# Dashboard to monitor kubernetes cluster
data "template_file" "convert-json-template" {
  template = file("./dashboard.tpl")

  vars = {
    cluster_name = "${var.cluster_name}"
  }
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/monitoring_dashboard
resource "google_monitoring_dashboard" "dashboard" {
  dashboard_json = data.template_file.convert-json-template.rendered
}


#################
#### SECRETS ####
#################

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret
# Create secrets in gcp for connection string, passwor for airflow UI, fernet key
resource "google_secret_manager_secret" "postgress_connection_string" {
  secret_id = "{{cookiecutter.workspace}}-{{cookiecutter.env}}-postgress_conn_string"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret" "admin_password" {
  secret_id = "{{cookiecutter.workspace}}-{{cookiecutter.env}}-admin_password"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret" "fernet_key" {
  secret_id = "{{cookiecutter.workspace}}-{{cookiecutter.env}}-fernet_key"
  replication {
    automatic = true
  }
}
# Generate random passwor, fernet_key 
resource "random_password" "admin_password" {
  length           = 10
  special          = true
  override_special = "!%@#$"
}

resource "random_password" "fernet_key" {
  length           = 45
  special          = true
  override_special = "!%@#$"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/secret_manager_secret_version
# Secrets injection to Secret Manager
resource "google_secret_manager_secret_version" "postgress_connection_string" {
  secret      = google_secret_manager_secret.postgress_connection_string.id
  secret_data = "${var.postgres_user_name}:${var.postgres_user_password}@airflow-pgbouncer/${var.postgres_database_name}"
}

resource "google_secret_manager_secret_version" "admin_password" {
  secret      = google_secret_manager_secret.admin_password.id
  secret_data = random_password.admin_password.result
}

resource "google_secret_manager_secret_version" "fernet_key" {
  secret      = google_secret_manager_secret.fernet_key.id
  secret_data = random_password.fernet_key.result
}


##########################
#### SELF SIGNED CERT ####
##########################
# Generate .crt, ,key, .pem
{% if cookiecutter.cert_name==None %}
resource "null_resource" "cert" {
  provisioner "local-exec" {
    environment = {
      CountryName            = "PL"
      StateOrProvinceName    = "Masovian"
      LocalityName           = "Warsaw"
      OrganizationName       = "Org Name"
      OrganizationalUnitName = "Org Unit"
      CommonName             = ""
      EmailAddress           = ""
    }
    command     = <<EOT
mkdir -p ./Certs

echo "[req]
default_bits  = 2048
distinguished_name = req_distinguished_name
req_extensions = req_ext
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
countryName = $CountryName
stateOrProvinceName = N/A
localityName = N/A
organizationName = Self-signed certificate
commonName = ${google_compute_address.static.address}: Self-signed certificate
[req_ext]
subjectAltName = @alt_names
[v3_req]
subjectAltName = @alt_names
[alt_names]
IP.1 = ${google_compute_address.static.address}
" > ./Certs/san.cnf

openssl req -x509 -nodes -days 730 -newkey rsa:2048 -keyout ./Certs/key.pem -out ./Certs/cert.pem -config ./Certs/san.cnf


#KEY
list_of_secrets=$(gcloud secrets list --filter="name:{{cookiecutter.workspace}}-{{cookiecutter.env}}-airee_key")
if [[ $list_of_secrets != "" ]]
then
    echo "Secret {{cookiecutter.workspace}}-{{cookiecutter.env}}-airee_key exists, add new version"
    gcloud secrets versions add "{{cookiecutter.workspace}}-{{cookiecutter.env}}-airee_key" \
        --data-file=./Certs/key.pem
else
    echo "Secret {{cookiecutter.workspace}}-{{cookiecutter.env}}-airee_key not exists, creating"
    gcloud secrets create "{{cookiecutter.workspace}}-{{cookiecutter.env}}-airee_key" \
        --data-file=./Certs/key.pem
fi

#CERT
list_of_secrets=$(gcloud secrets list --filter="name:{{cookiecutter.workspace}}-{{cookiecutter.env}}-airee_cert")
if [[ $list_of_secrets != "" ]]
then
    echo "Secret {{cookiecutter.workspace}}-{{cookiecutter.env}}-airee_cert exists, add new version"
    gcloud secrets versions add "{{cookiecutter.workspace}}-{{cookiecutter.env}}-airee_cert" \
        --data-file=./Certs/cert.pem
else
    echo "Secret {{cookiecutter.workspace}}-{{cookiecutter.env}}-airee_cert not exists, creating"
    gcloud secrets create "{{cookiecutter.workspace}}-{{cookiecutter.env}}-airee_cert" \
        --data-file=./Certs/cert.pem
fi

# Delete all files
rm -r ./Certs/

EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [google_compute_address.static]
}
{% endif %}
