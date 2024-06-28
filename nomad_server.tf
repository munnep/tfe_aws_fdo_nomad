
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

locals {
  retry_join = "provider=aws tag_key=NomadJoinTag tag_value=auto-join"
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

  user_data = templatefile("${path.module}/scripts/cloudinit_nomad_server.yaml", {
    server_count              = 1
    region                    = var.region
    cloud_env                 = "aws"
    retry_join                = local.retry_join
    nomad_version             = var.nomad_version
  })

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
    aws_network_interface_sg_attachment.sg2_attachment
  ]
}
