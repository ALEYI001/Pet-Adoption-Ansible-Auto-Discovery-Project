#!/bin/bash
sudo yum update -y
sudo yum install wget -y
sudo yum install git -y
sudo yum install maven -y
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
sudo tee /etc/yum.repos.d/jenkins.repo <<'EOF'
[jenkins]
name=Jenkins-stable
baseurl=https://pkg.jenkins.io/redhat-stable
gpgcheck=1
gpgkey=https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
enabled=1
EOF
sudo yum upgrade -y
sudo yum install jenkins java-11-openjdk-devel -y --nobest
sudo yum install epel-release java-11-openjdk-devel
sudo systemctl daemon-reload
sudo systemctl start jenkins
sudo systemctl enable jenkins 
echo "license_key: eu01xxc8eeb4e84123bb46f5efeca64bFFFFNRAL" | sudo tee -a /etc/newrelic-infra.yml
sudo curl -o /etc/yum.repos.d/newrelic-infra.repo https://download.newrelic.com/infrastructure_agent/linux/yum/el/7/x86_64/newrelic-infra.repo
sudo yum -q makecache -y --disablerepo="*" --enablerepop='newrelic-infra'
sudo yum install newrelic-infra -y --nobest
sudo hostnamectl set-hostname Jenkins-Server

