# Get the latest RHEL 9 AMI for us-east-1 (Red Hat official account)
data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat official AWS account
  filter {
    name   = "name"
    values = ["RHEL-9*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

//creating launch template 
resource "aws_launch_template" "stage_launch_config" {
  name                   = "${var.name}-stage-asg-config"
  image_id               = data.aws_ami.redhat.id
  instance_type          = "t2.medium"
  key_name               = var.key
  vpc_security_group_ids = [aws_security_group.stage_sg.id]
  user_data = base64encode(file("${path.module}/docker.sh"))
  lifecycle {create_before_destroy = true}
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.name}-stage-asg-config"
    }
  }
}

# Autoscaling group for the application
resource "aws_autoscaling_group" "stage_asg" {
  name                      = "${var.name}-stage-asg"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 1
  health_check_type         = "EC2"
  health_check_grace_period = 30
  vpc_zone_identifier       = var.private_subnets
  target_group_arns = [aws_lb_target_group.stage_atg.arn]
  force_delete              = true
  launch_template {
    id      = aws_launch_template.stage_launch_config.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "${var.name}-stage-asg"
    propagate_at_launch = true
  }
}

# auto scaling policy
resource "aws_autoscaling_policy" "stage_scale_out" {
  name                   = "${var.name}-Stage-scale-out-policy"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.stage_asg.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    target_value = 70.0
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}

# Create Security Group for ASG instances
resource "aws_security_group" "stage_sg" {
  name        = "${var.name}-stage-sg"
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
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    description = "outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.name}-stage-sg"
  }
}


# Security Group for the application Load Balancer
resource "aws_security_group" "alb_sg" {
  name        = "${var.name}-alb-sg"
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
    Name = "${var.name}alb-sg"
  }
}

# Create application load balancer
resource "aws_lb" "stage_alb" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnets
  enable_deletion_protection = false
  tags = {
    Name = "${var.name}-alb"
  }
}

# Target Group for ALB → ASG instances
resource "aws_lb_target_group" "stage_atg" {
  name     = "${var.name}-atg"
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
resource "aws_lb_listener" "stage_https_listener" {
  load_balancer_arn = aws_lb.stage_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.acm-cert.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stage_atg.arn
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
resource "aws_route53_record" "stage_record" {
  zone_id = data.aws_route53_zone.hosted-zone.zone_id
  name    ="stage.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_lb.stage_alb.dns_name
    zone_id                = aws_lb.stage_alb.zone_id
    evaluate_target_health = true
  }
}