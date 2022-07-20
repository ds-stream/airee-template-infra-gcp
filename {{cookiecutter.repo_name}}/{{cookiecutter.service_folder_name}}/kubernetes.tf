terraform {
  required_version = ">= 0.13"

  required_providers {
    github = {
      source  = "integrations/github"
      version = ">= 4.5.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.2"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.10.0"
    }
    flux = {
      source  = "fluxcd/flux"
      version = ">= 0.0.13"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "3.1.0"
    }
  }
}

# Use this data source to access the configuration of the Google Cloud provider.
data "google_client_config" "default" {}

# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs
provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace
# Creating 'airflow' namespace to deploy airflow yamls
resource "kubernetes_namespace" "airflow_cluster" {
  metadata {
    name = var.namespace
  }
  depends_on = [google_container_node_pool.webserver_nodepool]
}

# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map
# Config map stores Database connection params created in terraform process.
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
    POSTGRES_DB       = var.postgres_database_name
    POSTGRES_USER     = var.postgres_user_name
    POSTGRES_PASSWORD = var.postgres_user_password
  }
  depends_on = [
    kubernetes_namespace.airflow_cluster
  ]
}

# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service
# Service expose to static IP reserved in terraform process
resource "kubernetes_service" "airflow_service" {
  metadata {
    name = "airflow-webserver"
    namespace = var.namespace
    annotations = {
      "cloud.google.com/load-balancer-type" = "External"
      "networking.gke.io/internal-load-balancer-allow-global-access" = "true"
    }
  }
  spec {
    selector = {
      app = "airflow-webserver"
    }
    session_affinity = "ClientIP"
    port {
      name       = "https"
      port       = 443
      protocol   = "TCP"
      target_port = 8080
    }
    load_balancer_ip = "${google_compute_address.static.address}"
    type = "LoadBalancer"
  }
  depends_on = [google_compute_address.static]
}

#######################
########FLUX###########
#######################

# Workload identity service account for flux
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account
resource "google_service_account" "workload-identity-user-sa" {
  account_id   = var.workload_identity_user
  display_name = "Service Account For Flux to access GCR"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam
resource "google_project_iam_member" "gcr-pull-role" {
  role = "roles/storage.objectViewer" 
  member = "serviceAccount:${google_service_account.workload-identity-user-sa.email}"
  project = var.project_id
}

resource "google_project_iam_member" "workload_identity-role" {
  role   = "roles/iam.workloadIdentityUser"
  member = "serviceAccount:${var.project_id}.svc.id.goog[flux-system/${var.workload_identity_user}]"
  project = var.project_id
}

# Init token for flux
# Runner SA need "token creator role"
# Now Runner SA have owner role, that is why it have permission to all sa. In future it will have only permission it needs and
# we have to run google_service_account_iam_binding with Token Creator role for it. 
# resource "google_service_account_iam_binding" "token-creator-iam" {
#     service_account_id = "projects/-/serviceAccounts/${google_service_account.workload-identity-user-sa.email}"
#     role               = "roles/iam.serviceAccountTokenCreator"
#     members = [
#         "serviceAccount:${var.base_service_account}"
#     ]
# }

# https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep
resource "time_sleep" "wait_for_permissions" {
  depends_on = [google_service_account.workload-identity-user-sa]
  create_duration = "120s"
}

#https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/service_account_access_token
data "google_service_account_access_token" "default" {
  target_service_account = "${google_service_account.workload-identity-user-sa.email}"
  scopes                 = ["cloud-platform"]
  depends_on = [
    time_sleep.wait_for_permissions
  ]
}

#https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file
data "template_file" "docker_config_script" {
  template = "${file("${path.module}/kube_docker_registry_config.json")}"
  vars = {
    docker-username           = "oauth2accesstoken"
    docker-password           = "${data.google_service_account_access_token.default.access_token}"
    docker-server             = "gcr.io"
    auth                      = base64encode("oauth2accesstoken:${data.google_service_account_access_token.default.access_token}")
  }
}

# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret
resource "kubernetes_secret" "docker-registry" {
  metadata {
    name = "gcr-credentials"
    namespace = var.flux_namespace
  }

  data = {
    ".dockerconfigjson" = "${data.template_file.docker_config_script.rendered}"
  }

  type = "kubernetes.io/dockerconfigjson"
}


# Flux
provider "flux" {}

# https://registry.terraform.io/providers/fluxcd/flux/latest/docs/data-sources/install
# Used to generate Kubernetes manifests for deploying Flux.
data "flux_install" "main" {
  target_path      = var.target_path
  components_extra = ["image-reflector-controller", "image-automation-controller"]
}

# https://registry.terraform.io/providers/fluxcd/flux/latest/docs/data-sources/sync
# Used to generate manifests for reconciling the specified repository path on the cluster.
data "flux_sync" "main" {
  target_path = var.target_path
  url         = "ssh://git@github.com/${var.organization}/${var.repository_name}.git"
  branch      = var.branch
}

# https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs#configuration
provider "kubectl" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  load_config_file       = false
}

# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace
# Creating 'flux-system' namespace to deploy flux components
resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = var.flux_namespace
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
    ]
  }
}

# https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/data-sources/kubectl_file_documents
# This provider provides a data resource kubectl_file_documents to enable ease of splitting multi-document yaml content.
# Get a list of flux yamls to be installed
data "kubectl_file_documents" "install" {
  content = data.flux_install.main.content
}
# Get the repo URL for syncing
data "kubectl_file_documents" "sync" {
  content = data.flux_sync.main.content
}

# https://www.terraform.io/language/values/locals
# A local value assigns a name to an expression, so you can use the name multiple times within a module instead of repeating the expression.
locals {
  install = [for v in data.kubectl_file_documents.install.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
  sync = [for v in data.kubectl_file_documents.sync.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
}

# https://registry.terraform.io/providers/gavinbunney/kubectl/latest/docs/resources/kubectl_manifest
# Install Flux manifests
resource "kubectl_manifest" "install" {
  depends_on = [kubernetes_namespace.flux_system]
  for_each   = { for v in local.install : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  yaml_body  = each.value
}

resource "kubectl_manifest" "sync" {
  depends_on = [kubectl_manifest.install, kubernetes_namespace.flux_system]
  for_each   = { for v in local.sync : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  yaml_body  = each.value
}

# https://www.terraform.io/language/values/locals
# A local value assigns a name to an expression, so you can use the name multiple times within a module instead of repeating the expression.
locals {
  known_hosts = "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="
}

# https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key
# Creates a PEM (and OpenSSH) formatted private key for Github.
resource "tls_private_key" "github_deploy_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

# https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret
# Create kubernetes secret with Github information for flux
resource "kubernetes_secret" "main" {
  depends_on = [kubectl_manifest.install]

  metadata {
    name      = data.flux_sync.main.secret
    namespace = data.flux_sync.main.namespace
  }

  data = {
    known_hosts    = local.known_hosts
    identity       = tls_private_key.github_deploy_key.private_key_pem
    "identity.pub" = tls_private_key.github_deploy_key.public_key_openssh
  }
}

# Github
provider "github" {
  token = var.github_token
  owner = var.organization
}

# https://registry.terraform.io/providers/integrations/github/latest/docs/data-sources/repository
# To make sure the repository exists and the correct permissions are set.
data "github_repository" "main" {
  full_name = "${var.organization}/${var.repository_name}"
}

# https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_file
# Allows you to create and manage files within a GitHub repository.
resource "github_repository_file" "install" {
  repository          = data.github_repository.main.name
  file                = data.flux_install.main.path
  content             = data.flux_install.main.content
  branch              = var.branch
  overwrite_on_create = true
}

resource "github_repository_file" "sync" {
  repository          = var.repository_name
  file                = data.flux_sync.main.path
  content             = data.flux_sync.main.content
  branch              = var.branch
  overwrite_on_create = true
}

resource "github_repository_file" "kustomize" {
  repository          = var.repository_name
  file                = data.flux_sync.main.kustomize_path
  content             = data.flux_sync.main.kustomize_content
  branch              = var.branch
  overwrite_on_create = true
}

# https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_deploy_key
# For flux to fetch source
resource "github_repository_deploy_key" "flux" {
  title      = var.github_deploy_key_title
  repository = data.github_repository.main.name
  key        = tls_private_key.github_deploy_key.public_key_openssh
  read_only  = false
}
