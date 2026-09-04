resource "random_password" "db" {
  length  = 40
  special = true
}

resource "random_password" "master" {
  length  = 48
  special = true
}

resource "google_secret_manager_secret" "db_password" {
  project   = var.project_id
  secret_id = local.db_secret_name

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db.result
}

resource "google_secret_manager_secret" "master_password" {
  project   = var.project_id
  secret_id = local.master_secret_name

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "master_password" {
  secret      = google_secret_manager_secret.master_password.id
  secret_data = random_password.master.result
}
