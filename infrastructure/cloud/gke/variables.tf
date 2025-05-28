variable "project_id" {
  type        = string
  description = "The project ID to deploy to"
}

variable "region" {
  type    = string
  default = "europe-north1"
}

variable "cluster_name" {
  type    = string
  default = "my-gke-cluster"
}
