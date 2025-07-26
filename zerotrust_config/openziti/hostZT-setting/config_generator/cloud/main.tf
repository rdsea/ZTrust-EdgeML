provider "google" {
  project = "aalto-t313-cs-e4640"
  region  = "europe-north1"
  zone    = "europe-north1-a"
}


# VM Instances

resource "google_compute_instance" "ziti_controller_router" {
  name         = "ziti-controller-router"
  machine_type = "e2-medium"
  zone         = "europe-north1-a"
  tags = ["ziti", "controller"]
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  
  network_interface {
    network = "default"
    access_config {}
  }
  metadata = {
    ssh-keys = "hong3nguyen:${file("~/.ssh/id_ed25519.pub")}"
  }

  metadata_startup_script = file("ziti-cloud-init.sh")
}

resource "google_compute_instance" "cloud_messageq" {
  name         = "cloud-messageq"
  machine_type = "e2-medium"
  zone         = "europe-north1-a"
  tags = ["cloud-messageq", "ziti-app"]
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/hong3nguyen/database"
    ]
  }
  provisioner "file" {
    source      = "../../../../../applications/machine_learning/object_classification/src/database/"
    destination = "/home/hong3nguyen/database"
  }
  provisioner "file" {
    source      = "config.yaml"
    destination = "/home/hong3nguyen/database/config.yaml"
  }
  connection {
    type        = "ssh"
    user        = "hong3nguyen"
    private_key = file("~/.ssh/id_ed25519")
    host        = self.network_interface[0].access_config[0].nat_ip
    agent = true  
  }
  
  network_interface {
    network = "default"
    access_config {}
  }
  metadata = {
    ssh-keys = "hong3nguyen:${file("~/.ssh/id_ed25519.pub")}"
  }

  metadata_startup_script = templatefile("ziti-mq-init.sh.tmpl", {
    controller_ip = google_compute_instance.ziti_controller_router.network_interface[0].network_ip
    router_ip     = google_compute_instance.ziti_controller_router.network_interface[0].network_ip
  })
}

resource "google_compute_instance" "cloud_db" {
  name         = "cloud-db"
  machine_type = "e2-medium"
  zone         = "europe-north1-a"
  tags = ["cloud-db", "ziti-app"]
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  
  network_interface {
    network = "default"
    access_config {}
  }
  metadata = {
    ssh-keys = "hong3nguyen:${file("~/.ssh/id_ed25519.pub")}"
  }

  metadata_startup_script = templatefile("ziti-db-init.sh.tmpl", {
    controller_ip = google_compute_instance.ziti_controller_router.network_interface[0].network_ip
    router_ip     = google_compute_instance.ziti_controller_router.network_interface[0].network_ip
  })
}

resource "google_compute_instance" "jaeger" {
  name         = "jaeger"
  machine_type = "e2-medium"
  zone         = "europe-north1-a"
  tags = ["jaeger-db", "ziti-app"]
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  
  network_interface {
    network = "default"
    access_config {}
  }
  metadata = {
    ssh-keys = "hong3nguyen:${file("~/.ssh/id_ed25519.pub")}"
  }

  metadata_startup_script = file("ziti-jaeger-init.sh")
}


# Firewall Rules

resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_ziti" {
  name    = "allow-ziti"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["1280", "3022", "443", "27017", "6262", "10080", "10000", "8440-8443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_app" {
  name    = "allow-app"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["5672", "27017"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "allow_metric" {
  name    = "allow-metric"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["4317", "4318", "16686", "14268", "14250"]
  }

  source_ranges = ["0.0.0.0/0"]
}



output "ziti_controller_router_ip" {
  value = google_compute_instance.ziti_controller_router.network_interface[0].access_config[0].nat_ip
}

output "cloud_messageq_ip" {
  value = google_compute_instance.cloud_messageq.network_interface[0].access_config[0].nat_ip
}

output "cloud_db_ip" {
  value = google_compute_instance.cloud_db.network_interface[0].access_config[0].nat_ip
}

output "jaeger_ip" {
  value = google_compute_instance.jaeger.network_interface[0].access_config[0].nat_ip
}
