output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.vpc.id
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = [
    aws_subnet.pub-sub1.id,
    aws_subnet.pub-sub2.id
  ]
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = [
    aws_subnet.priv-sub1.id,
    aws_subnet.priv-sub2.id
  ]
}

output "key_name" {
  description = "Name of the EC2 key pair"
  value       = aws_key_pair.key.key_name
}

output "private_key_pem" {
  description = "Private key PEM file content"
  value       = tls_private_key.key.private_key_pem
  sensitive   = true
}
