
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