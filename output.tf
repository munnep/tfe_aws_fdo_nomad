output "IP_Addresses" {
  value = <<CONFIGURATION

It will take a little bit for setup to complete and the UI to become available.
Once it is, you can access the Nomad UI at:

http://${aws_eip.nomad_server-eip.public_ip}:4646/ui

Set the Nomad address, run the bootstrap, export the management token, set the token variable, and test connectivity:

export NOMAD_ADDR=http://${aws_eip.nomad_server-eip.public_ip}:4646
nomad acl bootstrap | grep -i secret | awk -F "=" '{print $2}' | xargs > nomad-management.token 
export NOMAD_TOKEN=$(cat nomad-management.token) 
nomad server members

Copy the token value and use it to log in to the UI:

cat nomad-management.token
CONFIGURATION
}

output "TFE_settings" {
  value = <<CONFIGURATION

tag_prefix                 = ${var.tag_prefix}
dns_hostname               = ${var.dns_hostname}
tfe-private-ip             = ${cidrhost(cidrsubnet(var.vpc_cidr, 8, 1), 22)}
tfe_password               = ${var.tfe_password}
tfe_license                = ${var.tfe_license}
dns_zonename               = ${var.dns_zonename}
pg_dbname                  = ${aws_db_instance.default.db_name}
pg_address                 = ${aws_db_instance.default.address}
rds_password               = ${var.rds_password}
tfe_bucket                 = "${var.tag_prefix}-bucket"
region                     = ${var.region}
tfe_release                = ${var.tfe_release}
certificate_email          = ${var.certificate_email}
redis_host                 = ${lookup(aws_elasticache_cluster.redis.cache_nodes[0], "address", "No redis created")}
key_data      = "${base64encode(nonsensitive(acme_certificate.certificate.private_key_pem))}"
ca_cert_data  = "${base64encode(local.full_chain)}"

CONFIGURATION
}

locals {
  namespace = "terraform-enterprise"
  full_chain = "${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}"
}