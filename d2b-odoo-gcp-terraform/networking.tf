resource "google_compute_network" "odoo" {
  name                    = local.network_name
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "odoo" {
  name                     = local.subnet_name
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.odoo.id
  ip_cidr_range            = "10.20.0.0/24"
  private_ip_google_access = true
}

resource "google_compute_global_address" "private_service_access" {
  name          = "${local.name_prefix}-odoo-${var.environment}-psa"
  project       = var.project_id
  address_type  = "INTERNAL"
  purpose       = "VPC_PEERING"
  prefix_length = 16
  network       = google_compute_network.odoo.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.odoo.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access.name]

  depends_on = [google_project_service.services]
}

resource "google_compute_router" "nat" {
  name    = "${local.name_prefix}-odoo-${var.environment}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.odoo.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${local.name_prefix}-odoo-${var.environment}-nat"
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.nat.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.odoo.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_firewall" "allow_lb_to_odoo" {
  name    = "${local.name_prefix}-odoo-${var.environment}-allow-lb"
  project = var.project_id
  network = google_compute_network.odoo.name

  direction     = "INGRESS"
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["d2b-odoo"]

  allow {
    protocol = "tcp"
    ports    = ["80", "8082"]
  }
}

resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${local.name_prefix}-odoo-${var.environment}-allow-iap-ssh"
  project = var.project_id
  network = google_compute_network.odoo.name

  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["d2b-odoo"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
