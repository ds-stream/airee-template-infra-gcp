terraform state rm kubernetes_config_map.airflow_cluster
terraform state rm kubernetes_namespace.airflow_cluster
terraform state rm kubernetes_namespace.flux_system
terraform state rm google_sql_user.users
terraform state rm google_sql_database.database
terraform destroy --auto-approve
