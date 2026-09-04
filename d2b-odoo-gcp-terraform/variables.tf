variable "project_id" {
  description = "GCP project hosting the Odoo dev environment."
  type        = string
  default     = ""
}

variable "region" {
  type    = string
  default = "europe-west4"
}

variable "zone" {
  type    = string
  default = "europe-west4-b"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "domain" {
  description = "Primary Odoo hostname."
  type        = string
  default     = "internal.odoo.data2bots.com"
}

variable "dns_zone_name" {
  description = "Existing Cloud DNS managed-zone name for data2bots.com. Example: data2bots-com."
  type        = string
}

variable "dns_zone_domain" {
  description = "DNS zone DNS name, including the trailing dot."
  type        = string
  default     = "data2bots.com."
}

variable "repo_url" {
  type    = string
  default = "https://github.com/Traybuns/d2b-odoo-test.git"
}

variable "repo_branch" {
  type    = string
  default = "main"
}

variable "vm_machine_type" {
  type    = string
  default = "e2-standard-4"
}

variable "vm_disk_size_gb" {
  type    = number
  default = 100
}

variable "cloudsql_tier" {
  type    = string
  default = "db-custom-2-7680"
}

variable "cloudsql_disk_size_gb" {
  type    = number
  default = 100
}

variable "cloudsql_postgres_version" {
  type    = string
  default = "POSTGRES_16"
}

variable "labels" {
  type = map(string)
  default = {
    application = "odoo"
    company     = "data2bots"
    environment = "dev"
    managed_by  = "terraform"
  }
}
