
terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.52.0"
    }
  }
}

provider "openstack" {
  # Leave this block empty if using environment variables from openrc
}

resource "openstack_compute_keypair_v2" "ssh_key" {
  name       = "hong3nguyen"
  public_key = file("~/.ssh/id_ed25519_2024.pub")  # Adjust to your key file
}

resource "openstack_compute_instance_v2" "ziti_vm" {
  name            = "ziti-controller-router"
  image_name      = "Ubuntu-22.04" # See note below if this name doesn't work
  flavor_name     = "standard.tiny"  # Or "standard.small", check Horizon > Flavors
  key_pair        = openstack_compute_keypair_v2.ssh_key.name
  security_groups = ["default", "public"] # You can modify/add your own

  network {
    name = "project_2001736"  
  }
  
  # key_pair = ""
  user_data = file("startup.sh")
}

resource "openstack_networking_secgroup_v2" "ziti_sg" {
  name        = "ziti-security-group"
  description = "Allow SSH and Ziti controller/router ports"
}

resource "openstack_networking_secgroup_rule_v2" "ssh_rule" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.ziti_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "controller_rule" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8440
  port_range_max    = 8440
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.ziti_sg.id
}

resource "openstack_networking_secgroup_rule_v2" "router_rule" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 3022
  port_range_max    = 3022
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.ziti_sg.id
}

