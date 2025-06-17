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
  region  = var.region
}

# ------------------------------
# Ziti Controller VM
# ------------------------------
resource "google_compute_instance" "ziti_controller_router" {
  name         = "ziti-controller-router"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interface {
    network       = "default"
    access_config {}
  }

  metadata_startup_script = file("setup_cloud_ctrl_router.sh")

  metadata = {
    ssh-keys = "hong3nguyen:${file("~/.ssh/id_ed25519_2024.pub")}"
  }

  tags = ["ziti", "controller"]
}

# ------------------------------
# Ziti Router VM
# ------------------------------
# resource "google_compute_instance" "ziti_router" {
#   name         = "ziti-router"
#   machine_type = var.machine_type
#   zone         = var.zone
#
#   boot_disk {
#     initialize_params {
#       image = "ubuntu-os-cloud/ubuntu-2204-lts"
#     }
#   }
#
#   network_interface {
#     network       = "default"
#     access_config {}
#   }
#
#   metadata_startup_script = file("router-startup.sh")
#
#   metadata = {
#     ssh-keys = "hong3nguyen:${file("~/.ssh/id_ed25519_2024.pub")}"
#   }
#
#   tags = ["ziti", "router"]
#}

# ------------------------------
# Application (MessageQ)
# ------------------------------
#
# resource "google_compute_instance" "message_q" {
#   name         = "cloud-messageq"
#   machine_type = var.machine_type
#   zone         = var.zone
#
#   boot_disk {
#     initialize_params {
#       image = "ubuntu-os-cloud/ubuntu-2204-lts"
#     }
#   }
#
#   network_interface {
#     network       = "default"
#     access_config {}
#   }
#
#   # metadata_startup_script = file("setup_cloud_messageq.sh")
#
#   metadata_startup_script = templatefile("setup_cloud_messageq.sh.tmpl", {
#     ziti_edge_controller_ip = google_compute_instance.ziti_controller_router.network_interface[0].network_ip
#     ziti_edge_router_ip     = google_compute_instance.ziti_controller_router.network_interface[0].network_ip
#   })
#
#   metadata = {
#     ssh-keys = "hong3nguyen:${file("~/.ssh/id_ed25519_2024.pub")}"
#   }
#
#   #depends_on = [google_compute_instance.ziti_edge_controller]
#
#   tags = ["cloud-messageq", "ziti-app"]
# }

# ------------------------------
# Application (Database)
# ------------------------------
# resource "google_compute_instance" "database" {
#   name         = "cloud-db"
#   machine_type = var.machine_type
#   zone         = var.zone
#
#   boot_disk {
#     initialize_params {
#       image = "ubuntu-os-cloud/ubuntu-2204-lts"
#     }
#   }
#
#   network_interface {
#     network       = "default"
#     access_config {}
#   }
#
#   #metadata_startup_script = file("setup_cloud_db.sh")
#
#   metadata_startup_script = templatefile("setup_cloud_db.sh.tmpl", {
#     ziti_edge_controller_ip = google_compute_instance.ziti_controller_router.network_interface[0].network_ip
#     ziti_edge_router_ip     = google_compute_instance.ziti_controller_router.network_interface[0].network_ip
#   })
#
#   metadata = {
#     ssh-keys = "hong3nguyen:${file("~/.ssh/id_ed25519_2024.pub")}"
#   }
#
#   tags = ["cloud-db", "ziti-app"]
# }
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
  name    = "allow-ziti-ports"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["1280", "443",  "6262", "10080", "8440-8443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# ------------------------------
# Outputs
# ------------------------------
output "controller_ip" {
  value = google_compute_instance.ziti_controller_router.network_interface[0].access_config[0].nat_ip
}
# output "messageq_ip" {
#   value = google_compute_instance.message_q.network_interface[0].access_config[0].nat_ip
# }
#
# output "router_ip" {
#   value = google_compute_instance.ziti_router.network_interface[0].access_config[0].nat_ip
# }
#
