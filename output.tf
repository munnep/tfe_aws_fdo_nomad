output "ssh_nomad_server" {
  value = "ssh ubuntu@${aws_eip.nomad_server-eip.public_ip}"
}

output "port_forwarding_nomad_portal" {
  value = "ssh -L 4646:localhost:4646 ubuntu@${aws_eip.nomad_server-eip.public_ip}"
}

output "ssh_nomad_client" {
  value = "ssh ubuntu@${aws_eip.nomad_client-eip.public_ip}"
}

output "tfe_appplication" {
  value = "https://${var.dns_hostname}.${var.dns_zonename}"
}