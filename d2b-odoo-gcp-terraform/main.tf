locals {
  name_prefix = "d2b"

  network_name = "${local.name_prefix}-odoo-${var.environment}-vpc"
  subnet_name  = "${local.name_prefix}-odoo-${var.environment}-subnet"
  vm_name      = "${local.name_prefix}-vm-odoo-${var.environment}-01"
  sa_name      = "${local.name_prefix}-sa-odoo-${var.environment}-runtime"
  sql_name     = "${local.name_prefix}-cloudsql-odoo-${var.environment}"

  db_secret_name     = "${local.name_prefix}-odoo-${var.environment}-db-password"
  master_secret_name = "${local.name_prefix}-odoo-${var.environment}-master-password"

  instance_group_name = "${local.name_prefix}-odoo-${var.environment}-ig"
}

resource "google_project_service" "services" {
  for_each = toset([
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "secretmanager.googleapis.com",
    "dns.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
