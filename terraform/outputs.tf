output "server_public_ips" {
  description = "Public IP of each server — use these as the SSH_HOST secrets."
  value       = { for env, vm in aws_instance.server : env => vm.public_ip }
}

output "server_urls" {
  description = "Open these in a browser after deploy."
  value       = { for env, vm in aws_instance.server : env => "http://${vm.public_ip}" }
}

output "ssh_commands" {
  description = "Ready-to-use SSH commands."
  value       = { for env, vm in aws_instance.server : env => "ssh -i ${var.project}-key.pem ubuntu@${vm.public_ip}" }
}

output "ssh_user" {
  description = "Username for the SSH_USER secret."
  value       = "ubuntu"
}

output "private_key_file" {
  description = "Local path to the PRIVATE key. Paste its CONTENTS into the GitHub SSH_KEY secret."
  value       = local_file.private_key.filename
}
