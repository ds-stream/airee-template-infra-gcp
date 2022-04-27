# TODO Add Kubernetes provider
# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/guides/getting-started#provider-setup
# add namespace and configmap

resource "google_compute_network" "private_network" {
  provider = google-beta
  project  = var.project_id
  name     = var.private_network_name
}

resource "google_compute_global_address" "private_ip_address" {
  provider      = google-beta
  project       = var.project_id
  name          = var.private-ip-address_name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.private_network.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  provider = google-beta

  network                 = google_compute_network.private_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "instance" {
  provider         = google-beta
  project          = var.project_id
  name             = "${var.database_instance_name}-${random_id.db_name_suffix.hex}"
  region           = var.region
  database_version = var.database_instance_version

  depends_on = [google_service_networking_connection.private_vpc_connection]

  settings {
    tier = "db-f1-micro"
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.private_network.id
    }
  }
  deletion_protection = false
}
resource "google_sql_user" "users" {
  name       = "airflow"
  instance   = google_sql_database_instance.instance.name
  password   = "airflow"
  depends_on = [google_sql_database_instance.instance]

}

resource "google_sql_database" "database" {
  name       = var.postgres_database_name
  instance   = google_sql_database_instance.instance.name
  depends_on = [google_sql_database_instance.instance]
}


resource "google_container_cluster" "primary" {
  name                     = var.cluster_name
  location                 = var.region
  remove_default_node_pool = true
  initial_node_count       = 1
  networking_mode          = "VPC_NATIVE"
  network                  = google_compute_network.private_network.name
  ip_allocation_policy {}
  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name           = var.additional_nodepool["name"]
  location       = var.region
  cluster        = google_container_cluster.primary.name
  node_count     = var.additional_nodepool["node_count"]
  node_locations = [var.zone]
  node_config {
    preemptible  = true
    machine_type = var.additional_nodepool["machine_type"]
    labels       = { "purpose" = var.additional_nodepool["name"] }
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  depends_on = [google_container_cluster.primary]
}

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
    labels       = { "purpose" = var.worker_nodepool["name"]}
    {% if cookiecutter.airflow_performance == 'micro' -%}
    {% elif cookiecutter.airflow_performance == 'small' -%}
    taint {
            key = "purpose"
            value = var.worker_nodepool["name"]
            effect = "NO_SCHEDULE"
          }
    {% elif cookiecutter.airflow_performance == 'standard' -%}
    taint {
            key = "purpose"
            value = var.worker_nodepool["name"]
            effect = "NO_SCHEDULE"
          }
    {% elif cookiecutter.airflow_performance == 'large' -%}
    taint {
            key = "purpose"
            value = var.worker_nodepool["name"]
            effect = "NO_SCHEDULE"
          }
    {%- endif %}
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  depends_on = [google_container_cluster.primary]
}

resource "google_container_node_pool" "scheduler_nodepool" {
  name           = var.scheduler_nodepool["name"]
  location       = var.region
  cluster        = google_container_cluster.primary.name
  node_count     = var.scheduler_nodepool["node_count"]
  node_locations = [var.zone]
  node_config {
    preemptible  = true
    machine_type = var.scheduler_nodepool["machine_type"]
    labels       = { "purpose" = var.scheduler_nodepool["name"] }
    {% if cookiecutter.airflow_performance == 'small' -%}
    {% elif cookiecutter.airflow_performance == 'standard' -%}
    {% elif cookiecutter.airflow_performance == 'large' -%}
    taint {
            key = "purpose"
            value = var.scheduler_nodepool["name"]
            effect = "NO_SCHEDULE"
          }
    {%- endif %}
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  depends_on = [google_container_cluster.primary]
}

resource "google_compute_disk" "nfs-disk" {
  name  = var.nfs_disk["name"]
  type  = var.nfs_disk["type"]
  zone  = var.zone
  size  = var.nfs_disk["size"]
  physical_block_size_bytes = 4096
}
