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

# ----------EBS /data----------

# 40 GB EBS volume for Harbor data
resource "aws_ebs_volume" "harbor_data" {
  availability_zone = aws_instance.harbor_ec2.availability_zone
  size              = 40
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "harbor-data"
  }
}

# Attach the volume to your EC2 instance
resource "aws_volume_attachment" "harbor_data_attach" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.harbor_data.id
  instance_id = aws_instance.harbor_ec2.id
}

# ----------Compute----------

resource "aws_instance" "harbor_ec2" {
  ami           = data.aws_ssm_parameter.ubuntu_2204.value
  instance_type = var.instance_type
  subnet_id     = aws_subnet.harbor_subnet.id
  vpc_security_group_ids = [aws_security_group.harbor_sg.id]
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

DOMAIN="harbor.flochai.com"
HARBOR_ADMIN_PASS="${var.harbor_admin_password}"
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get upgrade -y
apt-get install -y docker.io docker-compose wget certbot jq dnsutils
systemctl enable --now docker

DATADISK=$(lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print $1}' | grep -v nvme0n1 | head -n1 || true)
if [ -n "$${DATADISK:-}" ]; then
  mkfs.ext4 -F /dev/"$DATADISK"
  mkdir -p /data
  echo "/dev/$DATADISK /data ext4 defaults,nofail 0 2" >> /etc/fstab
  mount -a
else
  echo "WARN: No extra data disk found; skipping /data"
fi

PUBIP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || true)
for i in $(seq 1 60); do
  host -t A "$DOMAIN" | grep -q "$PUBIP" && break
  echo "Waiting for DNS $DOMAIN -> $PUBIP ($i/60)"; sleep 5
done

HARBOR_VERSION=v2.11.0
wget -q "https://github.com/goharbor/harbor/releases/download/$HARBOR_VERSION/harbor-online-installer-$HARBOR_VERSION.tgz" -P /opt
tar -xzf /opt/harbor-online-installer-$HARBOR_VERSION.tgz -C /opt
cd /opt/harbor

certbot certonly --standalone --non-interactive --agree-tos -m admin@"$DOMAIN" -d "$DOMAIN"

sudo mv harbor.yml.tmpl harbor.yml
sed -i 's/hostname: .*/hostname: harbor.flochai.com/' harbor.yml
sed -i 's/certificate: .*/certificate:/etc/letsencrypt/live/harbor.flochai.com/fullchain.pem/' harbor.yml
sed -i 's/private_key: .*/private_key: /etc/letsencrypt/live/harbor.flochai.com/privkey.pem' harbor.yml

./install.sh --with-trivy
EOF
               tags = {
    Name = "harbor-ec2"
  }
}

#Get EIP from Account
data "aws_eip" "harbor_eip" {
  id = "eipalloc-0f6bfd05edf4d7418"
}

# Attach EIP
resource "aws_eip_association" "harbor_eip_assoc" {
  instance_id   = aws_instance.harbor_ec2.id
  allocation_id = data.aws_eip.harbor_eip.id
}
