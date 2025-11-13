locals {
  name = "petclinic"
}

module "vpc" {
  source = "./module/vpc"
  name   = local.name
}

module "bastion" {
  source      = "./module/bastion"
  name        = local.name
  vpc         = module.vpc.vpc_id
  subnets     = module.vpc.public_subnet_ids
  private_key = module.vpc.private_key
  key_name    = module.vpc.keypair_name
}

module "nexus" {
  source              = "./module/nexus"
  name                = local.name
  vpc_id              = module.vpc.vpc_id
  subnet_id           = module.vpc.public_subnet_ids[0]
  subnet_ids          = [module.vpc.public_subnet_ids[0], module.vpc.public_subnet_ids[1]]
  key_pair_name       = module.vpc.keypair_name
  domain_name         = var.domain_name
  newrelic_api_key    = var.newrelic_api_key
  newrelic_account_id = var.newrelic_account_id
}

module "ansible" {
  source              = "./module/ansible"
  name                = local.name
  vpc_id              = module.vpc.vpc_id
  subnet_id           = [module.vpc.private_subnet_ids[0]]
  keypair_name        = module.vpc.keypair_name
  private_key         = module.vpc.private_key
  newrelic_api_key    = var.newrelic_api_key
  newrelic_account_id = var.newrelic_account_id
}

module "database" {
  source      = "./module/database"
  name        = local.name
  db_subnets  = [module.vpc.private_subnet_ids[0], module.vpc.private_subnet_ids[1]]
  vpc_id      = module.vpc.vpc_id
  stage_sg    = module.stage_asg.stage_sg
  prod_sg     = module.prod_asg.prod_sg
  db_username = data.vault_generic_secret.secrets.data["username"]
  db_password = data.vault_generic_secret.secrets.data["password"]
}

module "sonarqube" {
  source    = "./module/sonarqube"
  name      = local.name
  vpc_id    = module.vpc.vpc_id
  subnet_id = module.vpc.public_subnet_ids[1]
  key       = module.vpc.keypair_name
  domain_name = var.domain_name
  public_subnets = [module.vpc.public_subnet_ids[0], module.vpc.public_subnet_ids[1]]
}

module "stage_asg" {
  source          = "./module/stage_asg"
  name            = local.name
  key             = module.vpc.keypair_name
  private_subnets = [module.vpc.private_subnet_ids[0], module.vpc.private_subnet_ids[1]]
  public_subnets  = [module.vpc.public_subnet_ids[0], module.vpc.public_subnet_ids[1]]
  vpc_id          = module.vpc.vpc_id
  ansible_sg      = module.ansible.ansible_sg
  bastion_sg      = module.bastion.bastion_sg
  domain_name     = var.domain_name
}

module "prod_asg" {
  source          = "./module/prod_asg"
  name            = local.name
  key             = module.vpc.keypair_name
  private_subnets = [module.vpc.private_subnet_ids[0], module.vpc.private_subnet_ids[1]]
  public_subnets  = [module.vpc.public_subnet_ids[0], module.vpc.public_subnet_ids[1]]
  vpc_id          = module.vpc.vpc_id
  ansible_sg      = module.ansible.ansible_sg
  bastion_sg      = module.bastion.bastion_sg
  domain_name     = var.domain_name
}