output "vpc_id" {
  value = aws_vpc.vpc.id
}
output "pub-sub1_id" {
  value = aws_subnet.pub-sub1.id
}

output "pub-sub2_id" {
  value = aws_subnet.pub-sub2.id
}

output "priv-sub1_id" {
  value = aws_subnet.priv-sub1.id
}

output "priv-sub2_id" {
  value = aws_subnet.priv-sub2.id
}

output "key_pair_name" {
  value = aws_key_pair.public_key.key_name
}

output "private_key_pem" {
  value = local_file.private_key.content
}

output "private_key_path" {
	value = local_file.private_key.filename
}

output "public_route_table_id" {
	value = aws_route_table.public_rt.id
}

output "private_route_table_id" {
	value = aws_route_table.private_rt.id
}

output "internet_gateway_id" {
	value = aws_internet_gateway.igw.id
}

output "nat_gateway_id" {
	value = aws_nat_gateway.nat.id
}

output "nat_eip_id" {
	value = aws_eip.eip.id
}