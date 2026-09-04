data "google_dns_managed_zone" "data2bots" {
  name    = var.dns_zone_name
  project = var.project_id
}

resource "google_dns_record_set" "odoo" {
  name         = "${var.domain}."
  managed_zone = data.google_dns_managed_zone.data2bots.name
  project      = var.project_id
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_global_address.lb.address]
}
