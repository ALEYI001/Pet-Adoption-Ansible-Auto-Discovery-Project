output "bastion_public_ip" {
  value = aws_instance.bastion_server.public_ip
  description = "Public IP of the Bastion Host"
}