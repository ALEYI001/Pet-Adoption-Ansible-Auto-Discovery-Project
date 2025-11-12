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
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.name}-prod-asg-config"
    }
  }
  lifecycle {
    create_before_destroy = true
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
  force_delete              = true
  launch_template {
    id      = aws_launch_template.prod_launch_config.id
    version = "$Latest"
  }
  # target_group_arns = [aws_lb_target_group.prod_tg.arn]
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
    Name = "${var.name}-prod-sg"
  }
}