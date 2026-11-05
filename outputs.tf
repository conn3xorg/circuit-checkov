output "checkov_version" {
  description = "checkov release installed."
  value       = var.checkov_version
}

output "checkov_path" {
  description = "Path of the checkov command on each host."
  value       = "/usr/local/bin/checkov"
}
