variable "region" {
  default = "eu-west-3"
}

variable "instance_type" {
  default = "t3.medium"
}

variable "key_name" {
  description = "SSH key pair for EC2"
  type        = string
  default     = "chimera-key"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "harbor_admin_password" {
  description = "Admin password for Harbor UI"
  type        = string
  sensitive   = true
}
