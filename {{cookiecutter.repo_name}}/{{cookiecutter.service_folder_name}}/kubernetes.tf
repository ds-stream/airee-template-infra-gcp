data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

resource "kubernetes_namespace" "airflow_cluster" {
  metadata {
    name = var.namespace
  }
  depends_on = [google_container_node_pool.primary_preemptible_nodes]
}

resource "kubernetes_config_map" "airflow_cluster" {
  metadata {
    name      = "postgres-config"
    namespace = var.namespace
    labels = {
      app = "airflow-postgres"
    }
  }

  data = {
    POSTGRES_HOST     = "${google_sql_database_instance.instance.private_ip_address}"
    POSTGRES_DB       = "airflow_db"
    POSTGRES_USER     = "airflow"
    POSTGRES_PASSWORD = "airflow"
  }
  depends_on = [
    kubernetes_namespace.airflow_cluster
  ]
}