variable "port" {
  type    = number
  default = 2222
}

# CI sets these to install an older checkov first, then upgrades to the
# circuit's own pin by applying again without them.
variable "checkov_version" {
  type    = string
  default = null
}

variable "requirements_file" {
  type    = string
  default = null
}

module "checkov" {
  source = "../.."

  hosts                = { box = "127.0.0.1" }
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"
  checkov_version      = var.checkov_version
  requirements_file    = var.requirements_file
}

output "checkov_path" {
  value = module.checkov.checkov_path
}

output "checkov_version" {
  value = module.checkov.checkov_version
}
