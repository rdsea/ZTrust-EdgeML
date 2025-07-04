resource "google_compute_instance" "instance" {
  name         = var.name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.image
    }
  }

  network_interface {
    network       = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${file(var.ssh_public_key_path)}"
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.ssh_private_key_path)
    host        = self.network_interface[0].access_config[0].nat_ip
    agent       = true
  }

  dynamic "provisioner" {
    for_each = var.provisioners
    content {
      content     = provisioner.value.content
      destination = provisioner.value.destination
    }
  }

  tags = var.tags
}
