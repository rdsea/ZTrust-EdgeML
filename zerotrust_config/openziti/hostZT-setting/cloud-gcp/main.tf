terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.8.0"
    }
  }
}

provider "google" {
  project = "aalto-t313-cs-e4640"
  region  = "europe-north1"
}

# ------------------------------
# Ziti Controller VM
# ------------------------------
resource "google_compute_instance" "ziti_controller_router" {
  name         = "ziti-controller-router"
  machine_type = "e2-medium"
  zone         = "europe-north1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network       = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "hong3nguyen:${file("~/.ssh/id_ed25519.pub")}"
  }

  connection {
    type        = "ssh"
    user        = "hong3nguyen"
    private_key = file("~/.ssh/id_ed25519")
    host        = self.network_interface[0].access_config[0].nat_ip
    agent       = true
  }

  # provisioner "file" {
  #   content = templatefile("ziti-cloud-init.sh.tmpl", {})
  #   destination = "/tmp/ziti-cloud-init.sh"
  # }
  metadata_startup_script = file("ziti-cloud-init.sh")

  # provisioner "remote-exec" {
  #   inline = [
  #     "chmod +x /tmp/ziti-cloud-init.sh",
  #     "sudo /tmp/ziti-cloud-init.sh"
  #   ]
  # }

  tags = ["ziti", "controller"]
}

# ------------------------------
# Application (MessageQ)
# ------------------------------
resource "google_compute_instance" "message_q" {
  name         = "cloud-messageq"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network       = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "hong3nguyen:${file("~/.ssh/id_ed25519.pub")}"
  }

  connection {
    type        = "ssh"
    user        = "hong3nguyen"
    private_key = file("~/.ssh/id_ed25519")
    host        = self.network_interface[0].access_config[0].nat_ip
    agent       = true
  }

  # Provision application files first
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/hong3nguyen/app"
    ]
  }
  provisioner "file" {
    source      = "../../../../applications/machine_learning/object_classification/src/database/"
    destination = "/home/hong3nguyen/app/"
  }

  # Provision and run Ziti setup script
  metadata_startup_script = file("ziti-mq-init.sh")

  # provisioner "file" {
  #   content = templatefile("ziti-mq-init.sh.tmpl", {
  #     ziti_edge_controller_ip = google_compute_instance.ziti_controller_router.network_interface[0].network_ip,
  #     ziti_edge_router_ip = google_compute_instance.ziti_controller_router.network_interface[0].network_ip
  #   })
  #   destination = "/tmp/ziti-mq-init.sh"
  # }

  # provisioner "remote-exec" {
  #   inline = [
  #     "chmod +x /tmp/ziti-mq-init.sh",
  #     "sudo /tmp/ziti-mq-init.sh"
  #   ]
  # }

  tags = ["cloud-messageq", "ziti-app"]
}

# ------------------------------
# Application (Database)
# ------------------------------
resource "google_compute_instance" "database" {
  name         = "cloud-db"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network       = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "hong3nguyen:${file("~/.ssh/id_ed25519.pub")}"
  }

  connection {
    type        = "ssh"
    user        = "hong3nguyen"
    private_key = file("~/.ssh/id_ed25519")
    host        = self.network_interface[0].access_config[0].nat_ip
    agent       = true
  }

  metadata_startup_script = file("ziti-db-init.sh")
  # provisioner "file" {
  #   content = templatefile("ziti-db-init.sh.tmpl", {
  #     ziti_edge_controller_ip = google_compute_instance.ziti_controller_router.network_interface[0].network_ip,
  #     ziti_edge_router_ip = google_compute_instance.ziti_controller_router.network_interface[0].network_ip
  #   })
  #   destination = "/tmp/ziti-db-init.sh"
  # }
  #
  # provisioner "remote-exec" {
  #   inline = [
  #     "chmod +x /tmp/ziti-db-init.sh",
  #     "sudo /tmp/ziti-db-init.sh"
  #   ]
  # }

  tags = ["cloud-db", "ziti-app"]
}

# ------------------------------
# Shared Firewall Rules
# ------------------------------
resource "google_compute_firewall" "allow-ssh" {
  name    = "allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-ziti" {
  name    = "allow-ziti-app"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["1280", "3022", "443", "5672", "27017", "6262", "10080", "10000", "8440-8443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-app" {
  name    = "allow-app-messq-ports"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["5672"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# ------------------------------
# Outputs
# ------------------------------
output "controller_ip" {
  value = google_compute_instance.ziti_controller_router.network_interface[0].access_config[0].nat_ip
}
output "messageq_ip" {
  value = google_compute_instance.message_q.network_interface[0].access_config[0].nat_ip
}
output "database_ip" {
  value = google_compute_instance.database.network_interface[0].access_config[0].nat_ip
}
