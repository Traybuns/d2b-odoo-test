resource "google_compute_global_address" "lb" {
  name    = "${local.name_prefix}-odoo-${var.environment}-lb-ip"
  project = var.project_id
}

resource "google_compute_health_check" "odoo" {
  name    = "${local.name_prefix}-odoo-${var.environment}-hc"
  project = var.project_id

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 8082
    request_path = "/ping"
  }
}

resource "google_compute_backend_service" "odoo" {
  name                  = "${local.name_prefix}-odoo-${var.environment}-backend"
  project               = var.project_id
  protocol              = "HTTP"
  port_name             = "http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 60

  health_checks = [google_compute_health_check.odoo.id]

  backend {
    group           = google_compute_instance_group.odoo.id
    balancing_mode  = "UTILIZATION"
    max_utilization = 0.8
  }

  log_config {
    enable      = true
    sample_rate = 1
  }
}

resource "google_compute_url_map" "https" {
  name            = "${local.name_prefix}-odoo-${var.environment}-https-map"
  project         = var.project_id
  default_service = google_compute_backend_service.odoo.id

  host_rule {
    hosts        = [var.domain]
    path_matcher = "odoo"
  }

  path_matcher {
    name            = "odoo"
    default_service = google_compute_backend_service.odoo.id
  }
}

resource "google_compute_managed_ssl_certificate" "odoo" {
  name    = "${local.name_prefix}-odoo-${var.environment}-cert"
  project = var.project_id

  managed {
    domains = [var.domain]
  }
}

resource "google_compute_target_https_proxy" "odoo" {
  name             = "${local.name_prefix}-odoo-${var.environment}-https-proxy"
  project          = var.project_id
  url_map          = google_compute_url_map.https.id
  ssl_certificates = [google_compute_managed_ssl_certificate.odoo.id]
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "${local.name_prefix}-odoo-${var.environment}-https-fr"
  project               = var.project_id
  target                = google_compute_target_https_proxy.odoo.id
  port_range            = "443"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb.id
}

resource "google_compute_url_map" "http_redirect" {
  name    = "${local.name_prefix}-odoo-${var.environment}-http-redirect"
  project = var.project_id

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "redirect" {
  name    = "${local.name_prefix}-odoo-${var.environment}-http-proxy"
  project = var.project_id
  url_map = google_compute_url_map.http_redirect.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${local.name_prefix}-odoo-${var.environment}-http-fr"
  project               = var.project_id
  target                = google_compute_target_http_proxy.redirect.id
  port_range            = "80"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.lb.id
}
