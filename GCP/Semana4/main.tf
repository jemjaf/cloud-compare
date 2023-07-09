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

  source_ranges = ["38.25.23.185"]
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

  metadata_startup_script = file("./db-server.sh")

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

  metadata_startup_script = templatefile("./web-server.sh", { private_ip = google_compute_instance.rafita_db_instance.network_interface.0.network_ip })

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

#######################
# BigTable Instance
#######################
resource "google_bigtable_instance" "rafita_bigtable_instance" {
  name = "bigtable-instance-${local.environment}"

  cluster {
    cluster_id   = "bigtable-${local.environment}"
    zone         = "us-central1-b"
    storage_type = "HDD"
    num_nodes    = 1
  }
}

#######################
# BigTable Table
#######################
resource "google_bigtable_table" "table" {
  name          = "bigtable-table-${local.environment}"
  instance_name = google_bigtable_instance.rafita_bigtable_instance.name
}


output "key_copy" {
  value = "scp -i instance_key_pair.pem instance_key_pair.pem ubuntu@${google_compute_instance.rafita_app_instance.network_interface.0.access_config.0.nat_ip}:/home/ubuntu"
}

output "ssh_connect_app" {
  value = "ssh -i instance_key_pair.pem ubuntu@${google_compute_instance.rafita_app_instance.network_interface.0.access_config.0.nat_ip}"
}

output "ssh_connect_db" {
  value = "ssh -i instance_key_pair.pem ubuntu@${google_compute_instance.rafita_db_instance.network_interface.0.network_ip}"
}