
## Security Group for SonarQube Server ##
resource "aws_security_group" "sonarqube_sg" {
  name        = "${var.name}-sonarqube-sg"
  description = "Allow SSH, HTTP (Nginx), and HTTPS access"
  vpc_id      = var.vpc_id

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

# Attach SSM managed policy 
resource "aws_iam_role_policy_attachment" "sonarqube_ssm_attach" {
  role       = aws_iam_role.sonarqube_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "sonarqube_instance_profile" {
  name = "${var.name}-sonarqube-instance-profile"
  role = aws_iam_role.sonarqube_role.name
}

# data source to fetch latest ubuntu ami
data "aws_ami" "latest_ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
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
  ami                         = data.aws_ami.latest_ubuntu.id
  instance_type               = "t2.medium"
  key_name                    = var.key
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.sonarqube_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.sonarqube_instance_profile.name
  # User Data Script for all installation and configuration steps
  user_data = templatefile("${path.module}/sonarqube.sh", {

  })
  tags = {
    Name = "${var.name}-SonarQube_Server"
  }
}

#Creating sonarqube elastic load balancer
resource "aws_elb" "elb_sonar" {
  name            = "${var.name}-elb-sonar"
  security_groups = [aws_security_group.sonarqube_sg.id]
  subnets         = [aws_subnet.pub-sub1.id, aws_subnet.pub-sub2.id]
  listener {
    instance_port      = 80
    instance_protocol  = "http"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = data.aws_acm_certificate.acm-cert.arn

  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "tcp:80"
    interval            = 30
  }
  instances                   = [aws_instance.sonarqube_server.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
  tags = {
    Name = "${var.name}-sonar_elb"
  }
}

#creating A sonarqube record
resource "aws_route53_record" "sonarqube-record" {
  zone_id = data.aws_route53_zone.my-hosted-zone.zone_id
  name    = "sonarqube.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_elb.elb_sonar.dns_name
    zone_id                = aws_elb.elb_sonar.zone_id
    evaluate_target_health = true
  }
}

# Lookup the existing Route 53 hosted zone
data "aws_route53_zone" "my-hosted-zone" {
  name         = var.domain_name
  private_zone = false
}

# data block to fetch ACM certificate for Sonarqube
data "aws_acm_certificate" "acm-cert" {
  domain   = var.domain_name
  statuses = ["ISSUED"]
}