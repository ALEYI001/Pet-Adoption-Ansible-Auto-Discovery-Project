# Data source for latest RedHat AMI
data "aws_ami" "redhat" {
  most_recent = true
  owners      = ["309956199498"]
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

# Security group for Ansible server
resource "aws_security_group" "ansible_sg" {
  name        = "${var.name}-ansible-sg"
  description = "Allow ssh"
  vpc_id      = var.vpc_id

  ingress {
    description = "sshport"
    from_port   = 22
    to_port     = 22
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
    Name = "${var.name}-ansible-sg"
  }
}

# Ansible EC2 instance
resource "aws_instance" "ansible_server" {
  ami                    = data.aws_ami.redhat.id
  instance_type          = "t2.micro"
  key_name               = var.keypair_name
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]
  subnet_id              = var.subnet_id[0]
  iam_instance_profile = aws_iam_instance_profile.ansible_profile.id
  depends_on = [aws_s3_bucket_object.scripts1, aws_s3_bucket_object.scripts2]
  user_data = templatefile("${path.module}/ansible_userdata.sh", {
    private_key         = var.private_key
    newrelic_api_key    = var.newrelic_api_key
    newrelic_account_id = var.newrelic_account_id
    s3_bucket_name      = var.s3_bucket_name
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${var.name}-ansible-server"
  }
}

# IAM Role for Ansible
resource "aws_iam_role" "ansible_role" {
  name = "${var.name}-ansible-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_policy" {
  role       = aws_iam_role.ansible_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "s3_policy" {
  role       = aws_iam_role.ansible_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "ansible_profile" {
  name = "${var.name}-ansible-profile"
  role = aws_iam_role.ansible_role.name
}

# upload Ansible file to S3
resource "aws_s3_bucket_object" "scripts1" {
  bucket = var.s3_bucket_name
  key    = "scripts/test.txt"
  source = "${path.module}/scripts/test.txt"
}

# upload Ansible file to S3
resource "aws_s3_bucket_object" "scripts2" {
  bucket = var.s3_bucket_name
  key    = "scripts/test2.txt"
  source = "${path.module}/scripts/test2.txt"
}