locals {
  name = "set-26"
}

#this block creating a vpc
resource "aws_vpc" "set-26-vpc" {
    cidr_block = var.cidr
    enable_dns_support   = true
    enable_dns_hostnames = true
    instance_tenancy = "default"

tags = {
    Name = "${local.name}-vpc"
    }
}
# Create public subnets
resource "aws_subnet" "pub-sub1" {
    vpc_id = aws_vpc.set-26-vpc.id
    cidr_block = var.pub_sub1
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true

tags = {
    Name = "${local.name}-pub-subnet-1"
    }
}

resource "aws_subnet" "pub-sub2" {
    vpc_id = aws_vpc.set-26-vpc.id
    cidr_block = var.pub_sub2
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true

tags = {
    Name = "${local.name}-pub-subnet-2"
    }
}
# Create private subnets
resource "aws_subnet" "priv-sub1" {
    vpc_id = aws_vpc.set-26-vpc.id
    cidr_block = var.priv_sub1
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = false


tags = {
    Name = "${local.name}-priv-subnet-1"
    }
}

resource "aws_subnet" "priv-sub2" {
    vpc_id = aws_vpc.set-26-vpc.id
    cidr_block = var.priv_sub2
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = false


tags = {
    Name = "${local.name}-pri-subnet-2"
    }
}

#this block creating a security group
resource "aws_security_group" "set_26_sg" {
  name        = "set_26_sg"
  description = "Allowing inbound traffic"
  vpc_id      = aws_vpc.set-26-vpc.id

  ingress {
    description = "SSH"
    protocol    = "tcp"
    from_port   = var.sshport
    to_port     = var.sshport
    cidr_blocks = [var.allcidr]
  }
  ingress {
    description = "HTTP"
    protocol    = "tcp"
    from_port   = var.httpport
    to_port     = var.httpport
    cidr_blocks = [var.allcidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.allcidr]
  }

  tags = {
    Name = "${local.name}-sg"
  }
}

#  create security group for web application server
# resource "aws_security_group" "frontend_sg" {
#   name = "frontend_sg"
#   description = "Allowing inbound traffic"
#   vpc_id = aws_vpc.set-26-vpc.id

#   ingress {
#     description = "SSH"
#     protocol = "tcp"
#     from_port = var.sshport
#     to_port = var.sshport
#     cidr_blocks = [var.allcidr]
#   }
# ingress {
#         description = "HTTP-port"
#         protocol = "tcp"
#         from_port = var.httpport
#         to_port = var.httpport
#         cidr_blocks = [var.allcidr]
#     }
  
#   egress {
#     from_port = 0
#     to_port = 0
#     protocol = "-1"
#     cidr_blocks = [var.allcidr]
#   }
#   tags = {
#     Name = "${local.name}-frontend_sg"
#   }
# }

# # create security group for backend database application server 
# resource "aws_security_group" "backend_sg" {
#   name = "backend-sg"
#   description = "Allow all traffic from frontend_sg"
#   vpc_id = aws_vpc.set-26-vpc.id

#   ingress {
#     description = "Allow SSH from frontend_sg"
#     protocol = "tcp"
#     from_port = var.sshport
#     to_port = var.sshport
#     security_groups = [aws_security_group.frontend_sg.id]
    
#   }
#     ingress {
#         description = "AllowMYSQL/AURORA from frontend SG"
#         protocol = "tcp"
#         from_port = var.mysqlport
#         to_port = var.mysqlport
#         security_groups = [aws_security_group.frontend_sg.id]
#     }

#   egress {
#     from_port = 0
#     to_port = 0
#     protocol = "-1"
#     cidr_blocks = [var.allcidr]
#   }
  
#   tags = {
#     Name = "${local.name}-backend_sg"
#   }
# }

#  create internet gateway
resource "aws_internet_gateway" "set-26-igw" {
    vpc_id = aws_vpc.set-26-vpc.id

tags = {
    Name = "${local.name}-igw"
    }
}


#  this block creates nat gateway
resource "aws_nat_gateway" "set-26-nat" {
  allocation_id = aws_eip.set-26-eip.id
  subnet_id     = aws_subnet.pub-sub1.id
 depends_on = [aws_internet_gateway.set-26-igw]  # wait for the igw to be created frist before creating resource(nat gateway); 

  tags = {
    Name = "set-26-nat"
  } 
}
# this blolck creates a EPI(elastic ip) for nat gateway
resource "aws_eip" "set-26-eip" {
  domain   = "vpc"
}

#  create route table for public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.set-26-vpc.id


  route {
    cidr_block = var.allcidr
    gateway_id = aws_internet_gateway.set-26-igw.id
  }

  tags = {
    Name = "${local.name}-public-route-table"
  }
}

resource "aws_route_table_association" "pub-sub1" {
  subnet_id      = aws_subnet.pub-sub1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "pub-sub2" {
  subnet_id      = aws_subnet.pub-sub2.id
  route_table_id = aws_route_table.public_rt.id
}

# create route table for private subnet
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.set-26-vpc.id

  route {
    cidr_block = var.allcidr
    nat_gateway_id = aws_nat_gateway.set-26-nat.id
  }
    tags = {
        Name = "${local.name}-private-route-table"
    }
}
resource "aws_route_table_association" "priv-sub1" {
  subnet_id      = aws_subnet.priv-sub1.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "priv-sub2" {
  subnet_id      = aws_subnet.priv-sub2.id
  route_table_id = aws_route_table.private_rt.id
}
#  this block creates keypair
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "key" {
  content         = tls_private_key.key.private_key_pem
  filename        = "set26-key"
  file_permission = "600"
}
resource "aws_key_pair" "key" {
  key_name   = "set26-pub-key"
  public_key = tls_private_key.key.public_key_openssh
}
 