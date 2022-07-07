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
    tier = "db-g1-small"
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
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  depends_on = [google_service_networking_connection.private_vpc_connection]
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

resource "google_compute_disk" "nfs-disk" {
  name  = var.nfs_disk["name"]
  type  = var.nfs_disk["type"]
  zone  = var.zone
  size  = var.nfs_disk["size"]
  physical_block_size_bytes = 4096
  depends_on = [google_container_cluster.primary]
}

#########
## DNS ##
#########


resource "google_compute_address" "static" {
  name   = var.cluster_name
  region = var.region
  depends_on = [google_container_node_pool.webserver_nodepool]
}

{% if cookiecutter.domain!=None %}
resource "google_dns_record_set" "type_a" {
  name         = "${var.subdomain_name}.${var.domain_name}."
  managed_zone = var.dns_zone_name
  type         = "A"
  ttl          = 300

  rrdatas = ["${google_compute_address.static.address}"]
  depends_on = [google_compute_address.static]
}
{% endif %}

data "template_file" "convert-json-template" {
    template = file("./dashboard.tpl")

    vars = {
        cluster_name = "${var.cluster_name}"
    }
}

resource "google_monitoring_dashboard" "dashboard" {
  dashboard_json = data.template_file.convert-json-template.rendered
}

#############
## SECRETS ##
#############

resource "google_secret_manager_secret" "postgress_connection_string" {
  secret_id = "{{cookiecutter.workspace}}-postgress_conn_string"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret" "admin_password" {
  secret_id = "{{cookiecutter.workspace}}-admin_password"
  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret" "fernet_key" {
  secret_id = "{{cookiecutter.workspace}}-fernet_key"
  replication {
    automatic = true
  }
}

resource "random_password" "admin_password" {
  length = 10
  special = true
  override_special = "!%@#$"
}

resource "random_password" "fernet_key" {
  length = 45
  special = true
  override_special = "!%@#$"
}

resource "google_secret_manager_secret_version" "postgress_connection_string" {
  secret = google_secret_manager_secret.postgress_connection_string.id
  secret_data = "${var.postgres_user_name}:${var.postgres_user_password}@airflow-pgbouncer/${var.postgres_database_name}"
}

resource "google_secret_manager_secret_version" "admin_password" {
  secret = google_secret_manager_secret.admin_password.id
  secret_data = random_password.admin_password.result
}

resource "google_secret_manager_secret_version" "fernet_key" {
  secret = google_secret_manager_secret.fernet_key.id
  secret_data = random_password.fernet_key.result
}

######################
## SELF SIGNED CERT ##
######################

{% if cookiecutter.cert_name==None %}
resource "null_resource" "cert" {
  provisioner "local-exec" {
    environment = {
      CountryName = "PL"
      StateOrProvinceName = "Masovian"
      LocalityName = "Warsaw"
      OrganizationName="Org Name"
      OrganizationalUnitName="Org Unit"
      CommonName=""
      EmailAddress=""
    }
    command = <<EOT
mkdir -p ./Certs

# 0. Generate random password for generate priv key and pem file
rnd=`openssl rand -base64 32`
subj="/C=$CountryName/ST=$StateOrProvinceName/L=$LocalityName/O=$OrganizationName/CN=$CommonName"

# 1. Generate private key
openssl genrsa -passout pass:$rnd -des3 -out ./Certs/private.key 2048

# 2. Generate root certificate
openssl req -x509 -new -nodes -passin pass:$rnd -subj "$subj" -key ./Certs/private.key -sha256 -days 825 -out ./Certs/cert.pem

# 3. Generate a private key
openssl genrsa -out ./Certs/key.key 2048

# 4. Create a certificate-signing requesta
openssl req -new -subj "$subj" -key ./Certs/key.key -out ./Certs/csr.csr

# 5. Create a config file for the extensions
>./Certs/extensions.ext cat <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = ${google_compute_address.static.address}
EOF

# 6. Create the signed certificate

openssl x509 -req -passin pass:$rnd  -in ./Certs/csr.csr -CA ./Certs/cert.pem -CAkey ./Certs/private.key -CAcreateserial \
-out ./Certs/certificate.crt -days 825 -sha256 -extfile ./Certs/extensions.ext

# 7. Send data to gcloud

# CRT
list_of_secrets=$(gcloud secrets list --filter="name:{{cookiecutter.workspace}}_ariee_cert")
if [[ $list_of_secrets != "" ]]
then
    echo "Secret {{cookiecutter.workspace}}_ariee_cert exists, add new version"
    gcloud secrets versions add "{{cookiecutter.workspace}}_ariee_cert" \
        --data-file=./Certs/certificate.crt
else
    echo "Secret {{cookiecutter.workspace}}_ariee_cert not exists, creating"
    gcloud secrets create "{{cookiecutter.workspace}}_ariee_cert" \
        --data-file=./Certs/certificate.crt
fi

#KEY
list_of_secrets=$(gcloud secrets list --filter="name:{{cookiecutter.workspace}}_ariee_key")
if [[ $list_of_secrets != "" ]]
then
    echo "Secret {{cookiecutter.workspace}}_ariee_key exists, add new version"
    gcloud secrets versions add "{{cookiecutter.workspace}}_ariee_key" \
        --data-file=./Certs/key.key
else
    echo "Secret {{cookiecutter.workspace}}_ariee_key not exists, creating"
    gcloud secrets create "{{cookiecutter.workspace}}_ariee_key" \
        --data-file=./Certs/key.key
fi

#PEM
list_of_secrets=$(gcloud secrets list --filter="name:{{cookiecutter.workspace}}_ariee_pem")
if [[ $list_of_secrets != "" ]]
then
    echo "Secret {{cookiecutter.workspace}}_ariee_pem exists, add new version"
    gcloud secrets versions add "{{cookiecutter.workspace}}_ariee_pem" \
        --data-file=./Certs/cert.pem
else
    echo "Secret {{cookiecutter.workspace}}_ariee_pem not exists, creating"
    gcloud secrets create "{{cookiecutter.workspace}}_ariee_pem" \
        --data-file=./Certs/cert.pem
fi

# 8. Delete all files
rm -r ./Certs/

EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [google_compute_address.static]
}
{% endif %}