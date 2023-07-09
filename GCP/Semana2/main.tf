###################
# Cloud Storage
###################
resource "google_storage_bucket" "rafita_cloud_storage" {
  name                        = "${local.global_identifier}-bucket"
  uniform_bucket_level_access = true
  location                    = "us-east1"
}

resource "google_storage_bucket_object" "cloud_storage_folder" {
  name    = "${local.project_name}/"
  content = " "
  bucket  = google_storage_bucket.rafita_cloud_storage.name
}

##################
# VPC
##################
resource "google_compute_network" "rafita_vpc" {
  name         = "${local.project_name}-vpc"
  routing_mode = "REGIONAL"
}

resource "google_compute_subnetwork" "rafita_vpc_subnet" {
  name          = "${local.project_name}-subnet"
  ip_cidr_range = "10.0.0.0/24"
  network       = google_compute_network.rafita_vpc.id
}

##################
# App Firewall
##################
resource "google_compute_firewall" "app_fw_ingress" {
  name        = "${local.project_name}-app-fw-ingress"
  network     = google_compute_network.rafita_vpc.name
  description = "App security group - Ingress"
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["8000", "22"]
  }

  source_ranges = ["0.0.0.0/0"]
  source_tags   = ["app"]
}

###################
# Database Firewall
###################
resource "google_compute_firewall" "db_fw_ingress" {
  name        = "${local.project_name}-db-fw-ingress"
  network     = google_compute_network.rafita_vpc.name
  description = "Database security group - Ingress"
  direction   = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["5432", "22"]
  }

  source_ranges = [google_compute_subnetwork.rafita_vpc_subnet.ip_cidr_range]
  source_tags   = ["database"]
}

##################
# Filestore
##################
resource "google_filestore_instance" "rafita_filestore_instance" {
  name = local.global_identifier
  tier = "BASIC_HDD"

  file_shares {
    name        = "share1"
    capacity_gb = 1024
  }

  networks {
    network = google_compute_network.rafita_vpc.name
    modes   = ["ADDRESS_MODE_UNSPECIFIED"]
  }
}

###########
# Key Pair
###########
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "instance_key_pair" {
  filename        = "instance_key_pair.pem"
  content         = tls_private_key.rsa.private_key_pem
  file_permission = "0400"
}

#######################
# Database Instance
#######################
resource "google_compute_instance" "rafita_db_instance" {
  name         = "database-${local.global_identifier}"
  machine_type = "e2-micro"
  tags         = ["database"]

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-jammy-v20230616"
    }
  }

  metadata_startup_script = filebase64("db-server.sh")

  network_interface {
    network    = google_compute_network.rafita_vpc.name
    subnetwork = google_compute_subnetwork.rafita_vpc_subnet.name
    access_config {
      // Ephemeral public IP
      network_tier = "STANDARD"
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.rsa.public_key_openssh}"
  }
}

#######################
# App Instance
#######################
resource "google_compute_instance" "rafita_app_instance" {
  name         = "app-${local.global_identifier}"
  machine_type = "e2-micro"
  tags         = ["app"]

  boot_disk {
    initialize_params {
      image = "ubuntu-2204-jammy-v20230616"
    }
  }

  metadata_startup_script = base64encode(templatefile("./web-server.sh", { private_ip = google_compute_instance.rafita_db_instance.network_interface.0.network_ip }))

  network_interface {
    network    = google_compute_network.rafita_vpc.name
    subnetwork = google_compute_subnetwork.rafita_vpc_subnet.name
    access_config {
      // Ephemeral public IP
      network_tier = "STANDARD"
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.rsa.public_key_openssh}"
  }

  depends_on = [google_compute_instance.rafita_db_instance]
}

output "key_copy" {
  value = "scp -i instance_key_pair.pem instance_key_pair.pem ubuntu@${google_compute_instance.rafita_app_instance.network_interface.0.access_config.0.nat_ip}:/home/ubuntu"
}

output "ssh_connect_app" {
  value = "ssh -i instance_key_pair.pem ubuntu@${google_compute_instance.rafita_app_instance.network_interface.0.access_config.0.nat_ip}"
}

output "ssh_connect_db" {
  value = "ssh -i instance_key_pair.pem ubuntu@${google_compute_instance.rafita_db_instance.network_interface.0.access_config.0.nat_ip}"
}