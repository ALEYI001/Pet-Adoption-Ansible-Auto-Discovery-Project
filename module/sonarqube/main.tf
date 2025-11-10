
#this block creating a vpc
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy = "default"
  tags = {
      Name = "${var.name}-vpc"
  }
}

# import available azs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Create public subnets
resource "aws_subnet" "pub-sub1" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = data.aws_availability_zones.available.names[0]
    map_public_ip_on_launch = true

tags = {
    Name = "${var.name}-pub-subnet-1"
    }
}

resource "aws_subnet" "pub-sub2" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = data.aws_availability_zones.available.names[1]
    map_public_ip_on_launch = true

tags = {
    Name = "${var.name}-pub-subnet-2"
    }
}
# Create private subnets
resource "aws_subnet" "priv-sub1" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.3.0/24"
    availability_zone = data.aws_availability_zones.available.names[0]
    map_public_ip_on_launch = false

tags = {
    Name = "${var.name}-priv-subnet-1"
    }
}

resource "aws_subnet" "priv-sub2" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.4.0/24"
    availability_zone = data.aws_availability_zones.available.names[1]
    map_public_ip_on_launch = false

tags = {
    Name = "${var.name}-pri-subnet-2"
    }
}

#  create internet gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id

tags = {
    Name = "${var.name}-igw"
    }
}

#  this block creates nat gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.pub-sub1.id
 depends_on = [aws_internet_gateway.igw]  # wait for the igw to be created frist before creating resource(nat gateway); 

  tags = {
    Name = "${var.name}-nat"
  } 
}
# this blolck creates a EPI(elastic ip) for nat gateway
resource "aws_eip" "eip" {
  domain   = "vpc"
}

#  create route table for public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name}-public-route-table"
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
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
    tags = {
        Name = "${var.name}-private-route-table"
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
  filename        = "${var.name}-key.pem"
  file_permission = "640"
}

resource "aws_key_pair" "key" {
  key_name   = "${var.name}-key"
  public_key = tls_private_key.key.public_key_openssh
}
 

## Security Group for SonarQube Server ##
resource "aws_security_group" "sonarqube_sg" {
  name        = "SonarQube-SG"
  description = "Allow SSH, HTTP (Nginx), and HTTPS access"
  vpc_id      = aws_vpc.vpc.id

    # Ingress: SSH access from anywhere (for testing)
  ingress {
    description = "SSH Access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress: HTTP access for Nginx
  ingress {
    description = "HTTP Access for Nginx"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Egress: Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-sonarqube-sg"
  }
}


# Data block for IAM Policy Document
data "aws_iam_policy_document" "sonarqube_assume_role_policy" {
  statement {
    effect = "Allow"

    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}


# IAM Role and Instance Profile for SonarQube EC2 Instance
resource "aws_iam_role" "sonarqube_role" {
  name               = "${var.name}-sonarqube-role"
  assume_role_policy = data.aws_iam_policy_document.sonarqube_assume_role_policy.json
}

resource "aws_iam_instance_profile" "sonarqube_instance_profile" {
  name = "${var.name}-sonarqube-instance-profile"
  role = aws_iam_role.sonarqube_role.name
}

# data source to fetch latest ubuntu ami
data "aws_ami" "latest_ubuntu" {
  most_recent = true

  owners = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type" # hvm is hardware virtual machine for better performance
    values = ["hvm"]
  }
  filter {
        name   = "architecture" # x86_64 architecture is 64 bit architecture for servers
    values = ["x86_64"]
  }

}


## EC2 Instance for SonarQube
resource "aws_instance" "sonarqube_server" {
  ami                    = data.aws_ami.latest_ubuntu.id
  instance_type          = "t2.medium"
  key_name               = aws_key_pair.key.key_name
  subnet_id              =  aws_subnet.pub-sub1.id
  vpc_security_group_ids = [aws_security_group.sonarqube_sg.id]
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.sonarqube_instance_profile.name

  # User Data Script for all installation and configuration steps
  user_data = templatefile("${path.module}/sonarqube.sh", {
  
})


  tags = {
    Name = "${var.name}-SonarQube_Server"
  }
}

## Output the Public IP for access
output "sonarqube_public_ip" {
  description = "Public IP address of the SonarQube server"
  value       = aws_instance.sonarqube_server.public_ip
}