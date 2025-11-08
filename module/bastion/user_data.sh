#!/bin/bash
apt-get update -y
apt-get install -y unzip awscli fail2ban

# Install and start SSM agent
apt-get install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Enable and start Fail2ban for security hardening
systemctl enable fail2ban
systemctl start fail2ban

# Create directory and save private key securely
# echo "${private_key}" > /home/ubuntu/private-key.pem
# chmod 400 /home/ubuntu/private-key.pem
# chown ubuntu:ubuntu /home/ubuntu/private-key.pem

# Create SSH directory for ec2-user
mkdir -p /home/ubuntu/.ssh
# Copy the private key into the .ssh directory
echo "${private_key}" > /home/ubuntu/.ssh/id_rsa
# Set correct permissions and ownership
chmod 400 /home/ubuntu/.ssh/id_rsa
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa

# Disable root login
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart ssh

# Clean up cached packages
apt-get clean