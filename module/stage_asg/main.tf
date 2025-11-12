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
resource "aws_launch_template" "stage_launch_config" {
  name          = "${var.name}-stage-asg-config"
  image_id      = data.aws_ami.latest_amazon_linux.id
  instance_type = "t3.micro"
  key_name      = var.key
  vpc_security_group_ids = [aws_security_group.stage_sg.id]
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.name}-stage-asg-config"
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}


# Autoscaling group for the application
resource "aws_autoscaling_group" "stage_asg" {
  name                       = "${var.name}-stage-asg"
  max_size                   = 3
  min_size                   = 1
  desired_capacity           = 1
  health_check_type          = "EC2"
  health_check_grace_period  = 30
  vpc_zone_identifier        = [var.private_subnets]
  force_delete               = true
  launch_template {
  id      = aws_launch_template.stage_launch_config.id
  version = "$Latest"
  }
  # target_group_arns = [aws_lb_target_group.stage_tg.arn]
  tag  {
  key                 = "Name"
  value               = "${var.name}-stage-asg"
  propagate_at_launch = true
  }
}

# auto scaling policy
resource "aws_autoscaling_policy" "Stage_scale_out" {
  name                   = "Stage-scale-out-policy"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.stage_asg.name
  policy_type = "TargetTrackingScaling"
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
    description = "ssh port"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [var.ansible_sg, var.bastion_sg]
  }
  ingress {
    description = "application port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # allow web traffic
  }

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
resource "aws_lb" "app_alb" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg]
  subnets            = [var.public_subnets]
  enable_deletion_protection = false
  tags = {
    Name = "${var.name}-alb"
  }
  drop_invalid_header_fields = true
}

# Target Group for ALB → ASG instances
resource "aws_lb_target_group" "atg" {
  name     = "${var.name}-atg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check {
    path                = "/indextest.html"
    protocol            = "HTTP"
    interval            = 30 #that is 30 seconds
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 5
  }
  tags = {
    Name = "${var.name}-atg"
  }
}
# HTTP Listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.atg.arn
  }
}

# Create a Public Route 53 Hosted Zone
data "aws_route53_zone" "my-hosted-zone" {
  name         = var.domain_name
  private_zone = false
}

#Create DNS Record for Application Load Balancer
resource "aws_route53_record" "app_record" {
  zone_id = data.aws_route53_zone.my_hosted_zone.zone_id
  name    ="app.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_lb.app_alb.dns_name
    zone_id                = aws_lb.app_alb.zone_id
    evaluate_target_health = true
  }
}

# IAM Role and Instance Profile for EC2 (SSM + ELB) 
resource "aws_iam_role" "ec2_role" {
  name = "${var.name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}
# Attach AWS managed policy for SSM access Load Balancer
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
# Load Balancer full access
resource "aws_iam_role_policy_attachment" "elb_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}
# Create instance profile for EC2/ASG
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}
