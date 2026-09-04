resource "google_compute_address" "vm" {
  name         = "${local.name_prefix}-odoo-${var.environment}-vm-ip"
  project      = var.project_id
  region       = var.region
  address_type = "EXTERNAL"
}

resource "google_compute_instance" "odoo" {
  name         = local.vm_name
  project      = var.project_id
  zone         = var.zone
  machine_type = var.vm_machine_type
  tags         = ["d2b-odoo"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = var.vm_disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.odoo.id
    access_config {
      nat_ip = google_compute_address.vm.address
    }
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  service_account {
    email  = google_service_account.runtime.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  labels = var.labels

  metadata_startup_script = templatefile("${path.module}/startup.sh.tftpl", {
    repo_url            = var.repo_url
    repo_branch         = var.repo_branch
    project_id          = var.project_id
    domain              = var.domain
    db_name             = google_sql_database.internal.name
    db_user             = google_sql_user.odoo.name
    cloudsql_connection = google_sql_database_instance.odoo.connection_name
    db_secret_name      = google_secret_manager_secret.db_password.secret_id
    master_secret_name  = google_secret_manager_secret.master_password.secret_id
  })

  depends_on = [
    google_project_service.services,
    google_secret_manager_secret_version.db_password,
    google_secret_manager_secret_version.master_password,
    google_sql_database.internal,
    google_sql_user.odoo,
  ]
}

resource "google_compute_instance_group" "odoo" {
  name    = local.instance_group_name
  project = var.project_id
  zone    = var.zone

  instances = [google_compute_instance.odoo.self_link]

  named_port {
    name = "http"
    port = 80
  }

  named_port {
    name = "health"
    port = 8082
  }
}
