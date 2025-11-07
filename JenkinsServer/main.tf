locals {
  name = "utility"
  
}


# create vpc
resource "aws_vpc" "vpc" {
    cidr_block = var.cidr
    enable_dns_support = true
    enable_dns_hostnames = true
    instance_tenancy = "default"

tags = {
    Name = "${local.name}-vpc"
    }
}

# Create public subnets
resource "aws_subnet" "pub-sub1" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = var.pub_sub1
    availability_zone = "us-east-1a"

tags = {
    Name = "${local.name}-pub-subnet-1"
    }
}

resource "aws_subnet" "pub-sub2" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = var.pub_sub2
    availability_zone = "us-east-1b"

tags = {
    Name = "${local.name}-pub-subnet-2"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id

tags = {
    Name = "${local.name}-igw"
    }
}

# create route table for public subnet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id


  route {
    cidr_block = var.allcidr
    gateway_id = aws_internet_gateway.igw.id
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


resource "aws_iam_role" "instance_role" {
  name = "Jenkins-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_attach" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_instance_profile" "jenkins_instance_profile" {
  name = "Jenkins-profile"
  role = aws_iam_role.instance_role.name


  
}

# this block creates keypair
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "key" {
  content         = tls_private_key.key.private_key_pem
  filename        = "key"
  file_permission = "600"
}
resource "aws_key_pair" "public_key" {
  key_name   = "${local.name}-key"
  public_key = tls_private_key.key.public_key_openssh
}

#Security group for jenkins
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins_sg"
  description = "Allowing inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  
  ingress {
        description = "Jenkins-port"
        protocol = "tcp"
        from_port = var.jenkinsport
        to_port = var.jenkinsport
        cidr_blocks = [var.allcidr]
    }
  
  ingress {
        description = "Allow HTTP-port"
        protocol = "tcp"
        from_port = var.httpport
        to_port = var.httpport
        cidr_blocks = [var.allcidr]
    }
    
    ingress {
        description = "Allow HTTPS-port"
        protocol = "tcp"
        from_port = var.httpsport
        to_port = var.httpsport
        cidr_blocks = [var.allcidr]
    }

  ingress {
    description = "Allow SSH"
    from_port   = var.sshport 
    to_port     = var.sshport 
    protocol    = "tcp"
    cidr_blocks = [var.allcidr]
  }  

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.allcidr]
  }

  tags = {
    Name = "${local.name}-jenkins_sg"
  }
}


# instance and installing jenkins
resource "aws_instance" "jenkins" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.pub-sub2.id 
  key_name                    = aws_key_pair.public_key.key_name
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins_instance_profile.name
  associate_public_ip_address = true

  user_data = file("./jenkins_userdata.sh")
  

  tags = {
    Name = "${local.name}-jenkins"
  }
}

# Fetch existing Route53 hosted zone
data "aws_route53_zone" "work-experience2025" {
  name         = "work-experience2025.buzz"
  private_zone = false
  
}

# Request an ACM certificate 
resource "aws_acm_certificate" "app_cert" {
  domain_name       = "work-experience2025.buzz"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name}-jenkins-cert"
  }
}


# Create DNS validation record in Route53
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = var.zone_id 
  name    = each.value.name
  type    = each.value.type
  allow_overwrite = true
  ttl     = 60
  records = [each.value.record]
}

# Validate the acm certificate
resource "aws_acm_certificate_validation" "app_cert_validation" {
  certificate_arn         = aws_acm_certificate.app_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}


#creating Jenkins elb
resource "aws_elb" "elb-jenkins1" {
  name            = "elb-jenkins1"
  security_groups = [aws_security_group.jenkins_sg.id]
  subnets         = [aws_subnet.pub-sub1.id, aws_subnet.pub-sub2.id]

  listener {
    instance_port      = 8080
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = aws_acm_certificate.app_cert.arn
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 29
    target              = "tcp:8080"
    interval            = 30
  }

  instances                   = [aws_instance.jenkins.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400


  tags = {
    Name = "jenkins-elb"
  }
}

#creating A jenkins record
resource "aws_route53_record" "jenkins-record" {
  zone_id = var.zone_id 
  name    = "jenkins.work-experience2025.buzz"
  type    = "A"
  alias {
    name                   = aws_elb.elb-jenkins1.dns_name
    zone_id                = aws_elb.elb-jenkins1.zone_id
    evaluate_target_health = true
  }
}

# Create a DNS record pointing to the ELB
resource "aws_route53_record" "app_dns" {
  zone_id = data.aws_route53_zone.work-experience2025.zone_id
  name    = "app.work-experience2025.buzz"
  type    = "A"

  alias {
    name                   = aws_elb.elb-jenkins1.dns_name
    zone_id                = aws_elb.elb-jenkins1.zone_id
    evaluate_target_health = true
  }
}

