 user_data = <<-EOF
    #!/bin/bash
    set -e

    # Update system
    apt-get update -y && apt-get upgrade -y

    # Disable root SSH login for hardening
    sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    systemctl restart sshd

    # Install Fail2Ban for SSH brute-force protection
    apt-get install -y fail2ban

    # Setup directory for SSH key
    mkdir -p /home/ubuntu/.ssh
    echo "${file("~/.ssh/private_key.pem")}" > /home/ubuntu/.ssh/private_key.pem
    chmod 400 /home/ubuntu/.ssh/private_key.pem
    chown ubuntu:ubuntu /home/ubuntu/.ssh/private_key.pem

    # Optional: Configure ProxyJump / SSH Agent Forwarding (for admin use)
    echo "Host private-instance
      HostName <PRIVATE_INSTANCE_IP>
      User ubuntu
      IdentityFile ~/.ssh/private_key.pem
      ProxyJump bastion" >> /home/ubuntu/.ssh/config
    chown ubuntu:ubuntu /home/ubuntu/.ssh/config
    chmod 600 /home/ubuntu/.ssh/config
  EOF
}
