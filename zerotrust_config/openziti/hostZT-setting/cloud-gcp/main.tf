# provider "google" {
#   project     = var.project_id
#   region      = var.region
# }
#
# resource "google_compute_instance" "ziti_controller" {
#   name         = "ziti-controller"
#   machine_type = var.machine_type
#   zone         = var.zone
#
#   boot_disk {
#     initialize_params {
#       #image = "debian-cloud/debian-11"
#       image = "ubuntu-os-cloud/ubuntu-2204-lts"
#     }
#   }
#
#   network_interface {
#     network       = "default"
#     access_config {} # Adds external IP
#   }
#
#   metadata_startup_script = <<-EOF
#     #!/bin/bash
#     apt-get update
#     apt-get install -y docker.io git
#     systemctl start docker
#     docker run --name ziti-controller -d \
#       -p 1280:1280 -p 6262:6262 \
#       openziti/quickstart
#   EOF
#
#   tags = ["ziti"]
#
#   metadata = {
#     ssh-keys = "hong3nguyen:${file("~/.ssh/id_ed25519_2024.pub")}"
#   }
# }
#
# resource "google_compute_firewall" "ziti_fw" {
#   name    = "ziti-allow"
#   network = "default"
#
#   allow {
#     protocol = "tcp"
#     ports    = ["1280", "6262"]
#   }
#
#   source_ranges = ["0.0.0.0/0"]
#   target_tags   = ["ziti"]
# }
#
# terraform {
#   required_providers {
#     google = {
#       source  = "hashicorp/google"
#       version = "6.8.0"
#     }
#   }
# }
#
# provider "google" {
#   project     = "aalto-t313-cs-e4640"
#   region      = var.region
# }
#
# resource "google_compute_instance" "ziti_vm" {
#   name         = "ziti-combined-vm"
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
#   #metadata_startup_script = file("startup.sh")
#
#   metadata = {
#   ssh-keys = "hong3nguyen:${file("~/.ssh/id_ed25519_2024.pub")}"
#   }
#
#   tags = ["ziti"]
# }

# resource "google_compute_firewall" "allow-ssh" {
#   name    = "allow-ssh"
#   network = "default"
#
#   allow {
#     protocol = "tcp"
#     ports    = ["22"]
#   }
#
#   source_ranges = ["0.0.0.0/0"]
# }
#
# resource "google_compute_firewall" "allow-ziti" {
#   name    = "allow-ziti-ports"
#   network = "default"
#
#   allow {
#     protocol = "tcp"
#     ports    = ["1280", "6262", "10080", "8440-8443"]
#   }
#
#   source_ranges = ["0.0.0.0/0"]
# }


# output "vm_ip" {
#   value = google_compute_instance.ziti_vm.network_interface[0].access_config[0].nat_ip
# }

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

  metadata_startup_script = file("startup.sh")

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
#
# output "router_ip" {
#   value = google_compute_instance.ziti_router.network_interface[0].access_config[0].nat_ip
# }
#
