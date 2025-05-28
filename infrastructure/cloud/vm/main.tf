terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.17.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_compute_network" "object-detection-network" {
  name                    = "object-detection-network"
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "allow-http-https" {
  name    = "allow-http-https"
  network = google_compute_network.object-detection-network.id

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443", "5672", "9092", "9093", "15672", "27017"]
  }

  allow {
    protocol = "icmp"
  }

  target_tags   = ["http-server", "https-server"]
  direction     = "INGRESS"
  source_ranges = var.source_ranges
}

resource "google_compute_disk" "object-detection-disk" {
  count = 1
  name  = "object-detection-disk-${count.index}"
  size  = var.disk_size
  type  = "pd-balanced"
  zone  = var.zone
}

resource "google_compute_instance" "object-detection" {
  count        = 1
  name         = "object-detection-${count.index}"
  machine_type = var.instance_type

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = google_compute_network.object-detection-network.id
    access_config {}
  }

  metadata = {
    ssh-keys = "${var.ssh_username}:${file(var.public_key_path)}"
  }

  tags = ["http-server", "https-server"]

  connection {
    type        = "ssh"
    user        = var.ssh_username
    private_key = file(var.private_key_path)
    host        = self.network_interface[0].access_config[0].nat_ip
  }
}
