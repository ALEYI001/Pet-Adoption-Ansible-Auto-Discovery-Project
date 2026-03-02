#############################################################
Pet Adoption Auto-Discovery Platform Techinical Overview
#############################################################
This repository contains the Infrastructure as Code (IaC) and configuration management files for the Pet Adoption application.Key features; Production-grade, highly available DevSecOps architecture deployed on AWS using Terraform, Jenkins, Docker, Ansible, and integrated security tooling.



📌 Project Overview
This project demonstrates the design and deployment of a scalable, secure, multi-AZ cloud infrastructure for a containerized pet adoption application.
It implements:
•	Infrastructure as Code (Terraform)
•	CI/CD automation (Jenkins)
•	DevSecOps integration
•	Auto Scaling & Load Balancing
•	Multi-AZ high availability
•	Configuration management with Ansible
•	Artifact repository with Nexus
•	Monitoring & Alerting
############################################################
Architecture Highlights
•	Multi-AZ deployment (High Availability)
•	Public and Private subnet segmentation
•	Bastion-controlled administrative access
•	Auto Scaling Groups (Stage & Production)
•	Elastic Load Balancer
•	MongoDB & MySQL in private subnets
•	Secrets management with Vault
•	Security scanning (Checkov, Sonar, Trivy & OWASP ZAP)
############################################################
Architecture Overview
The infrastructure is deployed within the us-east-1 region across two Availability Zones (AZs) for redundancy. It utilizes a dual-VPC strategy to separate management tools from application resources.
1. Utility VPC (utility-vpc)
This VPC acts as the control plane for the entire operation. It houses:

Jenkins: The primary CI/CD engine responsible for orchestration.

HashiCorp Vault: Manages secrets, API keys, and certificates securely.

Integrated Toolchain: Includes Maven (build), Checkov/Terraform (IaC/Security), SonarQube (Static Analysis), Nexus (Artifact Registry), and security scanners like Trivy, OWASP Dependency Check, and Zap.

2. Infrastructure VPC (infrastructure-vpc)
The environment where the application lives, divided into tiers:

Public Subnets: Host the Bastion Auto Scaling Group (ASG) for secure administrative access and SonarQube/Nexus for analysis and storage.

Private Subnets: Host the application logic to prevent direct internet exposure.

Stage ASG: For pre-production testing and validation.

Prod ASG: The live production environment.

Ansible: Located in Private Subnet 1, it performs Auto Discovery and configuration management for the ASGs.

Database Layer: A Master-Slave (M/S) relational database setup for data persistence and failover.
############################################################
🔄 CI/CD Pipeline
Pipeline Flow:
1.	Code push to GitHub
2.	Jenkins triggers pipeline
3.	Docker image build
4.	Security scanning
5.	Push artifact to Nexus
6.	Terraform infrastructure provisioning
7.	Ansible configuration
8.  Security Scanning 
9.	Deploy to Stage
10.  Promote to production
############################################################
🔐 DevSecOps Integration
Security is embedded into the pipeline:
•	Code scanning (Chekov)
•	Static scanning (Sonarqube)
•	Container scanning (Trivy)
•	Dynamic app security testing (OWASP ZAP)
•	Secrets management (Vault)
•	Network isolation (Private subnets)
•	Least privilege access controls
############################################################
📊 Monitoring
•	New Relic for observability
•	Slack integration for alerts
############################################################
🚀 Techstack
•	AWS (EC2, VPC, ASG, ELB)
•	Terraform
•	Jenkins
•	Docker
•	Ansible
•	Nexus
•	Vault
•	Trivy
•	OWASP ZAP
•	MongoDB
•	MySQL
############################################################
DevOps Workflow
############################################################
Trigger: Developers push code or devops engineers push infrastructure changes to GitHub.

Continuous Integration: Jenkins pulls the code and runs the pipeline:

Scan: Checkov and Trivy audit the Terraform and Docker images.

Build: Maven compiles the application.

Test: Unit tests and SonarQube quality gates are applied.

Artifact Storage: Built images/binaries are pushed to Nexus.

Continuous Deployment: * Terraform updates the VPC and ASG infrastructure.

Ansible uses Auto Discovery to identify new EC2 instances in the ASGs.

Ansible pulls playbooks from S3 and deploys the latest artifacts from Nexus to the Stage/Prod targets.

Monitoring & Feedback: New Relic monitors performance, and Slack provides real-time notifications to the team.
############################################################
Additional documents
1. Architectural Justification Document:
2. Projects Challenges & Solutions:
3. Design Trade Offs:
4. Business Value Statement:
############################################################
👨🏽‍💻 Author

Aleyi, Inalegwu
Cloud / DevOps Engineer
############################################################
