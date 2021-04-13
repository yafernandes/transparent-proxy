terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.3.0"
    }
  }
}

provider "aws" {
  region                  = var.region
  shared_credentials_file = var.aws_credential_file
  profile                 = "default"
}

resource "aws_key_pair" "main" {
  key_name   = var.project_name
  public_key = file(var.ssh_public_key_file)
  tags = {
    Creator = var.creator
  }
}

resource "aws_network_interface" "proxy" {
  subnet_id         = aws_subnet.proxy.id
  security_groups   = [aws_security_group.proxy.id]
  source_dest_check = false
}

resource "aws_instance" "proxy" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.main.key_name

  network_interface {
    network_interface_id = aws_network_interface.proxy.id
    device_index         = 0
  }

  root_block_device {
    volume_size = 13
  }

  tags = {
    Name     = "${var.project_name} Squid"
    Creator  = var.creator
    dns_name = "squid"
  }

  volume_tags = {
    Name    = "${var.project_name} proxy"
    Creator = var.creator
  }
}

resource "aws_instance" "client" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.client.id
  vpc_security_group_ids = [aws_security_group.client.id]
  key_name               = aws_key_pair.main.key_name

  root_block_device {
    volume_size = 13
  }

  tags = {
    Name     = "${var.project_name} client"
    Creator  = var.creator
    dns_name = "client"
  }

  volume_tags = {
    Name    = "${var.project_name} client"
    Creator = var.creator
  }
}

