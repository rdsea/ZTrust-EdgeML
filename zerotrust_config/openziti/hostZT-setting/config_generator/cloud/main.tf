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
  region  = "us-central1"
}

module "ziti_controller_router" {
  source = "terraform-google-modules/vm/google//modules/compute_instance"

  name                  = "ziti-controller-router"
  machine_type          = "e2-medium"
  zone                  = "us-central1-a"
  source_image = "ubuntu-os-cloud/ubuntu-2204-lts"
  tags                  = ["ziti", "controller"]
  metadata_startup_script = file("ziti-cloud-init.sh")

  
}

module "message_q" {
  source = "terraform-google-modules/vm/google//modules/compute_instance"

  name                  = "cloud-messageq"
  machine_type          = "e2-medium"
  zone                  = "us-central1-a"
  source_image = "ubuntu-os-cloud/ubuntu-2204-lts"
  tags                  = ["cloud-messageq", "ziti-app"]

  metadata_startup_script = replace(
    file("ziti-mq-init.sh"),
    "add_ziti_dns_entries \"\" \"\"",
    "add_ziti_dns_entries \"${module.ziti_controller_router.network_interface[0].network_ip}\" \"${module.ziti_controller_router.network_interface[0].network_ip}\""
  )

  
}

module "database" {
  source = "terraform-google-modules/vm/google//modules/compute_instance"

  name                  = "cloud-db"
  machine_type          = "e2-medium"
  zone                  = "us-central1-a"
  source_image = "ubuntu-os-cloud/ubuntu-2204-lts"
  tags                  = ["cloud-db", "ziti-app"]

  metadata_startup_script = replace(
    file("ziti-db-init.sh"),
    "add_ziti_dns_entries \"\" \"\"",
    "add_ziti_dns_entries \"${module.ziti_controller_router.network_interface[0].network_ip}\" \"${module.ziti_controller_router.network_interface[0].network_ip}\""
  )

  
}

# module "jaeger" {
#   source = "terraform-google-modules/vm/google//modules/compute_instance"
#
#   name                  = "jaeger-db"
#   machine_type          = "e2-medium"
#   zone                  = "us-central1-a"
#   image                 = "ubuntu-os-cloud/ubuntu-2204-lts"
#   ssh_user              = "hong3nguyen"
#   ssh_public_key_path   = "~/.ssh/id_ed25519.pub"
#   ssh_private_key_path  = "~/.ssh/id_ed25519"
#   tags                  = ["jaeger-db", "ziti-metric"]
#
#   provisioners = [
#     {
#       content = templatefile("ziti-db-init.sh.tmpl", {
#         ziti_edge_controller_ip = module.ziti_controller_router.network_interface[0].network_ip,
#         ziti_edge_router_ip     = module.ziti_controller_router.network_interface[0].network_ip
#       })
#       destination = "/tmp/ziti-jaeger-init.sh"
#     },
#     {
#       inline = [
#         "chmod +x /tmp/ziti-jaeger-init.sh",
#       ]
#         "sudo /tmp/ziti-jaeger-init.sh"
#     }
#   ]
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
  name    = "allow-ziti-app"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["1280", "3022", "443", "6262", "10080", "10000", "8440-8443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-app" {
  name    = "allow-app-messq-ports"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["5672", "27017" ]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow-jaeger" {
  name    = "allow-app-messq-ports"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["4318" ]
  }

  source_ranges = ["0.0.0.0/0"]
}
# ------------------------------
# Outputs
# ------------------------------
output "controller_ip" {
  value = module.ziti_controller_router.network_interface[0].access_config[0].nat_ip
}
output "messageq_ip" {
  value = module.message_q.network_interface[0].access_config[0].nat_ip
}
output "database_ip" {
  value = module.database.network_interface[0].access_config[0].nat_ip
}
output "jaeger_ip" {
  value = module.jaeger.network_interface[0].access_config[0].nat_ip
}
