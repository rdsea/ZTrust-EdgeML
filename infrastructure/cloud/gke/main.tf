provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_compute_network" "gke_network" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = true
}


resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  # remove_default_node_pool = true
  initial_node_count  = 1
  deletion_protection = false

  network = google_compute_network.gke_network.name

  node_config {
    machine_type = "e2-medium"
    disk_type    = "pd-standard"
    disk_size_gb = 50
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

}

# resource "google_container_node_pool" "primary_nodes" {
#   name     = "${var.cluster_name}-node-pool"
#   location = var.region
#   cluster  = google_container_cluster.primary.name
#
#   node_config {
#     machine_type = "e2-medium"
#     disk_type    = "pd-standard"
#     disk_size_gb = 50
#     oauth_scopes = [
#       "https://www.googleapis.com/auth/cloud-platform",
#     ]
#   }
#
#   initial_node_count = 3
# }
