output "project_id" {
  value = var.project_id
}

output "vm_name" {
  value = google_compute_instance.odoo.name
}

output "vm_external_ip" {
  value = google_compute_address.vm.address
}

output "cloudsql_instance" {
  value = google_sql_database_instance.odoo.name
}

output "cloudsql_connection_name" {
  value = google_sql_database_instance.odoo.connection_name
}

output "load_balancer_ip" {
  value = google_compute_global_address.lb.address
}

output "odoo_url" {
  value = "https://${var.domain}"
}

output "db_secret_name" {
  value = google_secret_manager_secret.db_password.secret_id
}

output "master_secret_name" {
  value = google_secret_manager_secret.master_password.secret_id
}

output "runtime_service_account" {
  value = google_service_account.runtime.email
}
