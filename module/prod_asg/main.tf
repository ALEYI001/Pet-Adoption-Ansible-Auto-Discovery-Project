#  Get the Latest Amazon Linux 2 AMI
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

//creating launch template 
resource "aws_launch_template" "prod_launch_config" {
  name                   = "${var.name}-prod-asg-config"
  image_id               = data.aws_ami.latest_amazon_linux.id
  instance_type          = "t3.micro"
  key_name               = var.key
  vpc_security_group_ids = [aws_security_group.prod_sg.id]
  user_data = base64encode(file("${path.module}/docker.sh"))
  lifecycle {create_before_destroy = true}
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.name}-prod-asg-config"
    }
  }
}


# Autoscaling group for the application
resource "aws_autoscaling_group" "prod_asg" {
  name                      = "${var.name}-prod-asg"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 1
  health_check_type         = "EC2"
  health_check_grace_period = 30
  vpc_zone_identifier       = var.private_subnets
  target_group_arns = [aws_lb_target_group.atg.arn]
  force_delete              = true
  launch_template {
    id      = aws_launch_template.prod_launch_config.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "${var.name}-prod-asg"
    propagate_at_launch = true
  }
}

# auto scaling policy
resource "aws_autoscaling_policy" "prod_scale_out" {
  name                   = "prod-scale-out-policy"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.prod_asg.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    target_value = 70.0
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}

# Create Security Group for ASG instances
resource "aws_security_group" "prod_sg" {
  name        = "${var.name}-prod-sg"
  description = "Allow inbound SSH and HTTP traffic"
  vpc_id      = var.vpc_id

  ingress {
    description     = "ssh port"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [var.ansible_sg, var.bastion_sg]
  }
  ingress {
    description = "application port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [aws_security_group.prod_alb_sg.id]
  }
  egress {
    description = "outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-prod-sg"
  }
}


# Security Group for the application Load Balancer
resource "aws_security_group" "prod_alb_sg" {
  name        = "${var.name}-prod-alb-sg"
  description = "Allow inbound HTTP and HTTPS traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # allow HTTPS
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # outbound allowed
  }

  tags = {
    Name = "${var.name}-prod-alb-sg"
  }
}

# Create application load balancer
resource "aws_lb" "prod_alb" {
  name               = "${var.name}-prod-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.prod_alb_sg.id]
  subnets            = var.public_subnets
  enable_deletion_protection = false
  tags = {
    Name = "${var.name}-prod-alb"
  }
}

# Target Group for ALB → ASG instances
resource "aws_lb_target_group" "prod_atg" {
  name     = "${var.name}-prod-atg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30 
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 5
  }
  tags = {
    Name = "${var.name}-atg"
  }
}
# HTTP Listener
resource "aws_lb_listener" "prod_https_listener" {
  load_balancer_arn = aws_lb.prod_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.acm-cert.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prod_atg.arn
  }
}

# Create a Public Route 53 Hosted Zone
data "aws_route53_zone" "hosted-zone" {
  name         = var.domain_name
  private_zone = false
}

# data block to fetch ACM certificate for Nexus
data "aws_acm_certificate" "acm-cert" {
  domain   = var.domain_name
  statuses = ["ISSUED"]
}

#Create DNS Record for Application Load Balancer
resource "aws_route53_record" "prod_record" {
  zone_id = data.aws_route53_zone.hosted-zone.zone_id
  name    ="prod.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_lb.prod_alb.dns_name
    zone_id                = aws_lb.prod_alb.zone_id
    evaluate_target_health = true
  }
}