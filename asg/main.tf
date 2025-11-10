// aws provider block
provider "aws" {
  region = "us-east-1"
}

#  Get the Latest Amazon Linux 2 AMI
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
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
 

//creating launch template 
resource "aws_launch_template" "launch_config" {
  name          = "asg-config"
  image_id      = data.aws_ami.latest_amazon_linux.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.sg.id]
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.name}-sg"
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}
# Autoscaling group for the application
resource "aws_autoscaling_group" "app_asg" {
  name                       = "app-asg"
  max_size                   = 4
  min_size                   = 1
  desired_capacity           = 2
  health_check_type          = "EC2"
  health_check_grace_period  = 30
  vpc_zone_identifier        = [aws_subnet.pub-sub1.id, aws_subnet.pub-sub2.id]
  force_delete               = true
  launch_template {
  id      = aws_launch_template.launch_config.id
  version = "$Latest"
  }
  # target_group_arns = [aws_lb_target_group.app_tg.arn]
  tag  {
  key                 = "Name"
  value               = "app-asg-instance"
  propagate_at_launch = true
  }
}

# auto scaling policy
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out-policy"
  adjustment_type        = "ChangeInCapacity"
  # cooldown               = 300 #seconds before it reacts
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  policy_type = "TargetTrackingScaling"
  target_tracking_configuration {
    target_value = 50.0
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}
# Create Security Group for ASG instances
resource "aws_security_group" "sg" {
  name        = "sg"
  description = "Allow inbound SSH and HTTP traffic"
  vpc_id      = aws_vpc.vpc.id


  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-sg"
  }
}
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  instance_tenancy = "default"
  tags = {
      Name = "${var.name}-vpc"
  }
}
// iomport available azs in the region
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
