
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
    server_count              = 1
    region                    = var.region
    cloud_env                 = "aws"
    retry_join                = local.retry_join
    nomad_version             = var.nomad_version
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
    aws_network_interface_sg_attachment.sgclient_attachment
  ]
}
