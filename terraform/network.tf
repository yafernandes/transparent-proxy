data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

data "aws_availability_zones" "available" {
  state            = "available"
  exclude_zone_ids = ["us-west-2d"]
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = "true"

  tags = {
    Name    = var.project_name
    Creator = var.creator
  }
}

resource "aws_subnet" "proxy" {
  vpc_id                  = aws_vpc.main.id
  availability_zone_id    = data.aws_availability_zones.available.zone_ids[0]
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-proxy"
    Creator = var.creator
  }
}

resource "aws_subnet" "client" {
  vpc_id                  = aws_vpc.main.id
  availability_zone_id    = data.aws_availability_zones.available.zone_ids[0]
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-client"
    Creator = var.creator
  }
}

resource "aws_security_group" "proxy" {
  vpc_id = aws_vpc.main.id
  name   = "proxy_sg"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
    self        = true
  }

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.client.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  tags = {
    Name    = var.project_name
    Creator = var.creator
  }
}

resource "aws_security_group" "client" {
  vpc_id = aws_vpc.main.id
  name   = "client_sg"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "6"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "17"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name} proxy"
    Creator = var.creator
  }
}

resource "aws_security_group_rule" "proxy_access" {
  security_group_id        = aws_security_group.client.id
  type                     = "egress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.proxy.id
  // Avoid cycle dependency when destroying the environemnt
  depends_on = [aws_security_group.proxy, aws_security_group.client]
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = var.project_name
    Creator = var.creator
  }
}

resource "aws_route_table" "proxy" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name} proxy"
    Creator = var.creator
  }
}

resource "aws_route_table" "client" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block  = "0.0.0.0/0"
    instance_id = aws_instance.proxy.id
  }

  route {
    cidr_block = "${chomp(data.http.myip.body)}/32"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name} client"
    Creator = var.creator
  }
}

resource "aws_route_table_association" "proxy" {
  subnet_id      = aws_subnet.proxy.id
  route_table_id = aws_route_table.proxy.id
}

resource "aws_route_table_association" "client" {
  subnet_id      = aws_subnet.client.id
  route_table_id = aws_route_table.client.id
}

