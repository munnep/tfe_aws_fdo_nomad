data "http" "my_public_ip" {
  url = "https://ifconfig.co/json"
  request_headers = {
    Accept = "application/json"
  }
}

locals {
  ifconfig_co_json = jsondecode(data.http.my_public_ip.response_body)
  namespace        = "terraform-enterprise"
  full_chain       = "${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}"
  retry_join       = "provider=aws tag_key=NomadJoinTag tag_value=auto-join"
}


resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "${var.tag_prefix}-vpc"
  }
}

resource "aws_subnet" "public1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone = local.az1
  tags = {
    Name = "${var.tag_prefix}-public1"
  }
}

resource "aws_subnet" "public2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone = local.az2

  tags = {
    Name = "${var.tag_prefix}-public2"
  }
}

resource "aws_subnet" "private1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 11)
  availability_zone = local.az1
  tags = {
    Name = "${var.tag_prefix}-private1"
  }
}

resource "aws_subnet" "private2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 12)
  availability_zone = local.az2
  tags = {
    Name = "${var.tag_prefix}-private2"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.tag_prefix}-gw"
  }
}

resource "aws_route_table" "publicroutetable" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.tag_prefix}-route-table-gw"
  }
}

resource "aws_eip" "nateIP" {
  domain = "vpc"
}

resource "aws_nat_gateway" "NAT" {
  allocation_id = aws_eip.nateIP.id
  subnet_id     = aws_subnet.public1.id

  tags = {
    Name = "${var.tag_prefix}-nat"
  }
}

resource "aws_route_table" "privateroutetable" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NAT.id
  }

  tags = {
    Name = "${var.tag_prefix}-route-table-nat"
  }

}

resource "aws_route_table_association" "PublicRT1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.publicroutetable.id
}

resource "aws_route_table_association" "PublicRT2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.publicroutetable.id
}

resource "aws_route_table_association" "PrivateRT1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.privateroutetable.id
}

resource "aws_route_table_association" "PrivateRT2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.privateroutetable.id
}

resource "aws_security_group" "tfe_server_sg" {
  vpc_id      = aws_vpc.main.id
  name        = "tfe_server_sg"
  description = "tfe_server_sg"

  ingress {
    description = "https from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh from internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${local.ifconfig_co_json.ip}/32"]
  }

  ingress {
    description = "PostgreSQL from internal network"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "nomad"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "vault internal active-active"
    from_port   = 8201
    to_port     = 8201
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "nomad communication"
    from_port   = 4646
    to_port     = 4649
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    # cidr_blocks = ["${local.ifconfig_co_json.ip}/32", var.vpc_cidr]
  }

  ingress {
    description = "redis communication"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "icmp from internet"
    from_port   = 0
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.tag_prefix}-tfe_server_sg"
  }
}

resource "aws_s3_bucket" "tfe-bucket" {
  bucket        = "${var.tag_prefix}-bucket"
  force_destroy = true

  tags = {
    Name = "${var.tag_prefix}-bucket"
  }
}

resource "aws_s3_bucket" "tfe-bucket-software" {
  bucket        = "${var.tag_prefix}-software"
  force_destroy = true

  tags = {
    Name = "${var.tag_prefix}-software"
  }
}

resource "aws_s3_object" "certificate_artifacts_s3_objects" {
  for_each = toset(["certificate_pem", "issuer_pem", "private_key_pem"])

  bucket  = "${var.tag_prefix}-software"
  key     = each.key # TODO set your own bucket path
  content = lookup(acme_certificate.certificate, "${each.key}")
}

# fetch the arn of the SecurityComputeAccess policy
data "aws_iam_policy" "SecurityComputeAccess" {
  name = "SecurityComputeAccess"
}
# add the SecurityComputeAccess policy to IAM role connected to your EC2 instance
resource "aws_iam_role_policy_attachment" "SSM" {
  role       = aws_iam_role.role.name
  policy_arn = data.aws_iam_policy.SecurityComputeAccess.arn
}

resource "aws_iam_role" "role" {
  name = "${var.tag_prefix}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "profile" {
  name = "${var.tag_prefix}-instance"
  role = aws_iam_role.role.name
}

resource "aws_iam_role_policy" "policy" {
  name = "${var.tag_prefix}-bucket"
  role = aws_iam_role.role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:GetBucketLocation"
        ],
        "Resource" : [
          "arn:aws:s3:::${var.tag_prefix}-bucket",
          "arn:aws:s3:::${var.tag_prefix}-software",
          "arn:aws:s3:::*/*"
        ]
      },
      {
        "Sid" : "VisualEditor1",
        "Effect" : "Allow",
        "Action" : "s3:ListAllMyBuckets",
        "Resource" : "*"
      },
      {
        "Sid" : "VisualEditor2",
        "Effect" : "Allow",
        "Action" : "ec2:DescribeInstances",
        "Resource" : "*"
      }
    ]
  })
}


# code idea from https://itnext.io/lets-encrypt-certs-with-terraform-f870def3ce6d
data "aws_route53_zone" "base_domain" {
  name = var.dns_zonename
}

resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "registration" {
  account_key_pem = tls_private_key.private_key.private_key_pem
  email_address   = var.certificate_email
}

resource "acme_certificate" "certificate" {
  account_key_pem = acme_registration.registration.account_key_pem
  common_name     = "${var.dns_hostname}.${var.dns_zonename}"

  recursive_nameservers        = ["1.1.1.1:53"]
  disable_complete_propagation = true

  dns_challenge {
    provider = "route53"

    config = {
      AWS_HOSTED_ZONE_ID = data.aws_route53_zone.base_domain.zone_id
    }
  }

  depends_on = [acme_registration.registration]
}

resource "aws_acm_certificate" "cert" {
  certificate_body  = acme_certificate.certificate.certificate_pem
  private_key       = acme_certificate.certificate.private_key_pem
  certificate_chain = acme_certificate.certificate.issuer_pem
}

resource "aws_key_pair" "default-key" {
  key_name   = "${var.tag_prefix}-key"
  public_key = var.public_key
}

resource "aws_db_subnet_group" "default" {
  name       = "${var.tag_prefix}-db-subnet-group"
  subnet_ids = [aws_subnet.private1.id, aws_subnet.private2.id]

  tags = {
    Name = "My DB subnet group"
  }
}

resource "aws_db_instance" "default" {
  allocated_storage      = 10
  engine                 = "postgres"
  engine_version         = "12"
  instance_class         = "db.t3.large"
  username               = "postgres"
  password               = var.rds_password
  parameter_group_name   = "default.postgres12"
  skip_final_snapshot    = true
  db_name                = "tfe"
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.tfe_server_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.default.name
  identifier             = "${var.tag_prefix}-rds"
  tags = {
    "Name" = var.tag_prefix
  }

}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}
resource "aws_elasticache_subnet_group" "redis" {
  name       = "redis"
  subnet_ids = [aws_subnet.private1.id]
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "redis-tfe"
  engine               = "redis"
  node_type            = "cache.t3.small"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  security_group_ids   = [aws_security_group.tfe_server_sg.id]
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
}



# nomad client server

resource "aws_network_interface" "nomad_client-priv" {
  subnet_id   = aws_subnet.public1.id
  private_ips = [cidrhost(cidrsubnet(var.vpc_cidr, 8, 1), 24)]

  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_network_interface_sg_attachment" "sgclient_attachment" {
  security_group_id    = aws_security_group.tfe_server_sg.id
  network_interface_id = aws_network_interface.nomad_client-priv.id
}

resource "aws_eip" "nomad_client-eip" {
  domain = "vpc"

  instance                  = aws_instance.nomad_client.id
  associate_with_private_ip = aws_network_interface.nomad_client-priv.private_ip
  depends_on                = [aws_internet_gateway.gw]

  tags = {
    Name = "${var.tag_prefix}-client-eip"
  }
}

resource "aws_route53_record" "tfe-instance" {
  zone_id = data.aws_route53_zone.base_domain.zone_id
  name    = var.dns_hostname
  type    = "A"
  ttl     = "300"
  records = [aws_eip.nomad_client-eip.public_ip]
  depends_on = [
    aws_eip.nomad_client-eip
  ]
}


resource "aws_instance" "nomad_client" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.2xlarge"
  key_name      = "${var.tag_prefix}-key"

  network_interface {
    network_interface_id = aws_network_interface.nomad_client-priv.id
    device_index         = 0
  }

  iam_instance_profile = aws_iam_instance_profile.profile.name

  user_data = templatefile("${path.module}/scripts/cloudinit_nomad_client.yaml", {
    server_count      = 1
    region            = var.region
    cloud_env         = "aws"
    retry_join        = local.retry_join
    nomad_version     = var.nomad_version
    dns_hostname      = var.dns_hostname
    dns_zonename      = var.dns_zonename
    certificate_email = var.certificate_email
    tfe_password      = var.tfe_password
  })

  root_block_device {
    volume_size = 40
  }

  # NomadJoinTag is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.tag_prefix}-client"
    },
    {
      "NomadJoinTag" = "auto-join"
    },
    {
      "NomadType" = "client"
    }
  )

  depends_on = [
    aws_network_interface_sg_attachment.sgclient_attachment, aws_db_instance.default, aws_elasticache_cluster.redis
  ]
}


# nomad server

resource "aws_network_interface" "nomad_server-priv" {
  subnet_id   = aws_subnet.public1.id
  private_ips = [cidrhost(cidrsubnet(var.vpc_cidr, 8, 1), 23)]

  tags = {
    Name = "primary_network_interface"
  }
}

resource "aws_network_interface_sg_attachment" "sg2_attachment" {
  security_group_id    = aws_security_group.tfe_server_sg.id
  network_interface_id = aws_network_interface.nomad_server-priv.id
}

resource "aws_eip" "nomad_server-eip" {
  domain = "vpc"

  instance                  = aws_instance.nomad_server.id
  associate_with_private_ip = aws_network_interface.nomad_server-priv.private_ip
  depends_on                = [aws_internet_gateway.gw]



  tags = {
    Name = "${var.tag_prefix}-client-eip"
  }
}

resource "aws_instance" "nomad_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"
  key_name      = "${var.tag_prefix}-key"

  network_interface {
    network_interface_id = aws_network_interface.nomad_server-priv.id
    device_index         = 0
  }

  iam_instance_profile = aws_iam_instance_profile.profile.name

  user_data = base64gzip(templatefile("${path.module}/scripts/cloudinit_nomad_server.yaml", {
    server_count      = 1
    region            = var.region
    cloud_env         = "aws"
    retry_join        = local.retry_join
    nomad_version     = var.nomad_version
    tag_prefix        = var.tag_prefix
    dns_hostname      = var.dns_hostname
    tfe-private-ip    = cidrhost(cidrsubnet(var.vpc_cidr, 8, 1), 22)
    tfe_password      = var.tfe_password
    tfe_license       = var.tfe_license
    dns_zonename      = var.dns_zonename
    pg_dbname         = aws_db_instance.default.db_name
    pg_address        = aws_db_instance.default.address
    rds_password      = var.rds_password
    tfe_bucket        = "${var.tag_prefix}-bucket"
    region            = var.region
    tfe_release       = var.tfe_release
    certificate_email = var.certificate_email
    redis_host        = lookup(aws_elasticache_cluster.redis.cache_nodes[0], "address", "No redis created")
    full_chain        = base64encode("${acme_certificate.certificate.certificate_pem}${acme_certificate.certificate.issuer_pem}")
    private_key_pem   = base64encode(lookup(acme_certificate.certificate, "private_key_pem"))
    nomad_client      = cidrhost(cidrsubnet(var.vpc_cidr, 8, 1), 24)
    nomad_server      = cidrhost(cidrsubnet(var.vpc_cidr, 8, 1), 23)
  }))

  # NomadJoinTag is necessary for nodes to automatically join the cluster
  tags = merge(
    {
      "Name" = "${var.tag_prefix}-server"
    },
    {
      "NomadJoinTag" = "auto-join"
    },
    {
      "NomadType" = "server"
    }
  )

  depends_on = [
    aws_network_interface_sg_attachment.sg2_attachment, aws_db_instance.default, aws_elasticache_cluster.redis
  ]
}
