output "harbor_public_ip" {
  value = data.aws_eip.harbor_eip.public_ip
}

output "harbor_public_dns" {
  value = aws_instance.harbor_ec2.public_dns
}
