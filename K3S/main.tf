provider "aws" {
  region = var.region
}

data "aws_ssm_parameter" "ubuntu_2204" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

output "ubuntu_ami_id" {
  value = data.aws_ssm_parameter.ubuntu_2204.value
  sensitive = true
}

# ----------Networking----------

# VPC
resource "aws_vpc" "k3s_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Subnet
resource "aws_subnet" "k3s_subnet" {
  vpc_id                  = aws_vpc.k3s_vpc.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
}

# Internet Gateway
resource "aws_internet_gateway" "k3s_igw" {
  vpc_id = aws_vpc.k3s_vpc.id
}

# Route Table
resource "aws_route_table" "k3s_rt" {
  vpc_id = aws_vpc.k3s_vpc.id
}

resource "aws_route" "k3s_internet" {
  route_table_id         = aws_route_table.k3s_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.k3s_igw.id
}

resource "aws_route_table_association" "k3s_rta" {
  subnet_id      = aws_subnet.k3s_subnet.id
  route_table_id = aws_route_table.k3s_rt.id
}

# Security Group
resource "aws_security_group" "k3s_sg" {
  vpc_id = aws_vpc.k3s_vpc.id
  name   = "k3s-sg"

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# ----------Compute----------

resource "aws_instance" "k3s_ec2" {
  ami           = data.aws_ssm_parameter.ubuntu_2204.value
  instance_type = var.instance_type
  subnet_id     = aws_subnet.k3s_subnet.id
  vpc_security_group_ids = [aws_security_group.k3s_sg.id]
  key_name      = var.key_name

  associate_public_ip_address = true

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

user_data = <<EOF
#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data-run.log | logger -t user-data -s 2>/dev/console) 2>&1

# baseline
apt-get update -y && apt-get upgrade -y
apt-get install -y curl git jq btop wget

# install k3s server with embedded etcd and servicelb
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -

# wait until k3s is up
sleep 30

# kubeconfig for ubuntu user
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
chmod 600 /home/ubuntu/.kube/config

# install Helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# create namespace for argocd
kubectl create namespace argocd

# install Argo CD core
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.3/cert-manager.yaml

# download and install K9s
cd /home/ubuntu
wget https://github.com/derailed/k9s/releases/download/v0.50.13/k9s_linux_amd64.deb
apt install -y ./k9s_linux_amd64.deb
chown ubuntu:ubuntu /home/ubuntu/k9s_linux_amd64.deb

# mark done
touch /var/log/user-data-done
EOF

               tags = {
    Name = "k3s-ec2"
  }
}

