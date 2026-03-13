# Pet Adoption Auto-Discovery Platform – Technical Overview

This repository contains the **Infrastructure as Code (IaC)** and configuration management files for the **Pet Adoption Application**.

Key features include a **production-grade, highly available DevSecOps architecture** deployed on AWS using **Terraform, Jenkins, Docker, Ansible**, and integrated security tooling.

---

# 📌 Project Overview

This project demonstrates the design and deployment of a **scalable, secure, multi-AZ cloud infrastructure** for a containerized pet adoption application.

It implements:

- Infrastructure as Code (**Terraform**)
- CI/CD automation (**Jenkins**)
- **DevSecOps** integration
- **Auto Scaling & Load Balancing**
- **Multi-AZ High Availability**
- Configuration management with **Ansible**
- Artifact repository with **Nexus**
- **Monitoring & Alerting**

---

# Architecture Highlights

- Multi-AZ deployment (**High Availability**)
- Public and Private subnet segmentation
- Bastion-controlled administrative access
- Auto Scaling Groups (**Stage & Production**)
- Elastic Load Balancer
- MongoDB & MySQL in private subnets
- Secrets management with **Vault**
- Security scanning (**Checkov, SonarQube, Trivy & OWASP ZAP**)

---

# Architecture Overview

The infrastructure is deployed within the **us-east-1** region across **two Availability Zones (AZs)** for redundancy.

It utilizes a **dual-VPC strategy** to separate management tools from application resources.

---

## 1. Utility VPC (`utility-vpc`)

This VPC acts as the **control plane** for the entire operation.

It houses:

- **Jenkins** – Primary CI/CD engine responsible for orchestration  
- **HashiCorp Vault** – Secure management of secrets, API keys, and certificates  

### Integrated Toolchain

- **Maven** – Application build
- **Checkov / Terraform** – IaC validation & security
- **SonarQube** – Static code analysis
- **Nexus** – Artifact registry
- **Trivy** – Container security scanning
- **OWASP Dependency Check**
- **OWASP ZAP** – Dynamic application security testing

---

## 2. Infrastructure VPC (`infrastructure-vpc`)

This VPC hosts the **application runtime environment**.

### Public Subnets

- Bastion **Auto Scaling Group (ASG)** for secure administrative access
- **SonarQube & Nexus** for analysis and artifact storage

### Private Subnets

Hosts the application services to **prevent direct internet exposure**.

Components include:

- **Stage ASG** – Pre-production testing and validation
- **Prod ASG** – Live production environment

### Configuration Management

- **Ansible** (located in Private Subnet 1)
- Performs **Auto Discovery and configuration management** for instances inside the ASGs

### Database Layer

- **Master–Slave relational database architecture**
- Provides **data persistence and failover capability**

---

# CI/CD Pipeline

### Pipeline Flow

1. Code push to **GitHub**
2. **Jenkins** triggers pipeline
3. **Docker** image build
4. Security scanning
5. Push artifact to **Nexus**
6. **Terraform** infrastructure provisioning
7. **Ansible** configuration
8. Security scanning
9. Deploy to **Stage**
10. Promote to **Production**

---

# DevSecOps Integration

Security is embedded throughout the pipeline:

1. Code scanning (**Checkov**)
2. Static code analysis (**SonarQube**)
3. Container scanning (**Trivy**)
4. Dynamic application security testing (**OWASP ZAP**)
5. Secrets management (**Vault**)
6. Network isolation (**Private Subnets**)
7. Least privilege **access control policies**

---

# Monitoring

- **New Relic** – Observability and performance monitoring
- **Slack Integration** – Alerting and operational notifications

---

# Tech Stack

- AWS (**EC2, VPC, ASG, ELB**)
- Terraform
- Jenkins
- Docker
- Ansible
- Nexus
- Vault
- Trivy
- OWASP ZAP
- MongoDB
- MySQL

---

# DevOps Workflow

### Trigger

Developers push application code or DevOps engineers push infrastructure changes to **GitHub**.

---

### Continuous Integration

Jenkins pulls the repository and executes the pipeline:

**Scan**

- Checkov audits Terraform configurations
- Trivy scans Docker images

**Build**

- Maven compiles the application

**Test**

- Unit tests run
- **SonarQube quality gates** applied

**Artifact Storage**

- Built images/binaries are pushed to **Nexus**

---

### Continuous Deployment

- **Terraform** updates infrastructure (VPC, ASGs, networking)
- **Ansible Auto Discovery** identifies new EC2 instances inside ASGs
- Ansible pulls **playbooks from S3**
- Latest artifacts are deploye
