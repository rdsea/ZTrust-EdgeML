variable "name" {
  type = string
}

variable "machine_type" {
  type = string
}

variable "zone" {
  type = string
}

variable "image" {
  type = string
}

variable "ssh_user" {
  type = string
}

variable "ssh_public_key_path" {
  type = string
}

variable "ssh_private_key_path" {
  type = string
}

variable "provisioners" {
  type = list(object({
    content     = string
    destination = string
  }))
  default = []
}

variable "tags" {
  type    = list(string)
  default = []
}
