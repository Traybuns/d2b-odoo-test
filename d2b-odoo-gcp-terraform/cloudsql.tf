resource "google_sql_database_instance" "odoo" {
  name             = local.sql_name
  project          = var.project_id
  region           = var.region
  database_version = var.cloudsql_postgres_version

  deletion_protection = true

  settings {
    tier                  = var.cloudsql_tier
    availability_type     = "ZONAL"
    disk_type             = "PD_SSD"
    disk_size             = var.cloudsql_disk_size_gb
    disk_autoresize       = true
    disk_autoresize_limit = 500

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
    }

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.odoo.id
      enable_private_path_for_google_cloud_services = true
    }

    maintenance_window {
      day          = 7
      hour         = 2
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = true
      query_plans_per_minute  = 5
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = false
    }
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "google_sql_database" "internal" {
  name     = "d2b_odoo_internal"
  instance = google_sql_database_instance.odoo.name
  project  = var.project_id
}

resource "google_sql_user" "odoo" {
  name     = "odoo"
  instance = google_sql_database_instance.odoo.name
  project  = var.project_id
  password = random_password.db.result
}
