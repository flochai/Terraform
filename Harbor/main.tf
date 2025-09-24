provider "aws" {
  region = var.region
}

data "aws_ssm_parameter" "ubuntu_2204" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

output "ubuntu_ami_id" {
  value = data.aws_ssm_parameter.ubuntu_2204.value
}

# ----------Networking----------

# VPC
resource "aws_vpc" "harbor_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Subnet
resource "aws_subnet" "harbor_subnet" {
  vpc_id                  = aws_vpc.harbor_vpc.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
}

# Internet Gateway
resource "aws_internet_gateway" "harbor_igw" {
  vpc_id = aws_vpc.harbor_vpc.id
}

# Route Table
resource "aws_route_table" "harbor_rt" {
  vpc_id = aws_vpc.harbor_vpc.id
}

resource "aws_route" "harbor_internet" {
  route_table_id         = aws_route_table.harbor_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.harbor_igw.id
}

resource "aws_route_table_association" "harbor_rta" {
  subnet_id      = aws_subnet.harbor_subnet.id
  route_table_id = aws_route_table.harbor_rt.id
}

# Security Group
resource "aws_security_group" "harbor_sg" {
  vpc_id = aws_vpc.harbor_vpc.id
  name   = "harbor-sg"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Harbor Notary/Trivy (optional)"
    from_port   = 4443
    to_port     = 4443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----------Compute----------

# EC2 Instance
resource "aws_instance" "harbor_ec2" {
  ami           = data.aws_ssm_parameter.ubuntu_2204.value
  instance_type = var.instance_type
  subnet_id     = aws_subnet.harbor_subnet.id
  vpc_security_group_ids = [aws_security_group.harbor_sg.id]
  key_name      = var.key_name

  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              apt-get install -y docker.io docker-compose wget
              systemctl enable --now docker

              # Download Harbor installer
              wget https://github.com/goharbor/harbor/releases/download/v2.11.0/harbor-online-installer-v2.11.0.tgz -P /opt
              tar -xvf /opt/harbor-online-installer-v2.11.0.tgz -C /opt
              EOF

  tags = {
    Name = "harbor-ec2"
  }
}

# Elastic IP
resource "aws_eip" "harbor_eip" {
  instance = aws_instance.harbor_ec2.id
  vpc      = true
}
