###################
# DNS Zone
###################
resource "google_dns_managed_zone" "dns-zone" {
  visibility  = "public"
  name        = "${local.global_identifier}-zone"
  dns_name    = "zone.${local.global_identifier}.com."
  description = "${local.global_identifier} DNS zone"
  cloud_logging_config {
    enable_logging = true
  }
}

resource "google_dns_record_set" "frontend" {
  name = "frontend.${google_dns_managed_zone.dns-zone.dns_name}"
  type = "A"
  ttl  = 300

  managed_zone = google_dns_managed_zone.dns-zone.name

  rrdatas = ["8.8.8.8"]
}