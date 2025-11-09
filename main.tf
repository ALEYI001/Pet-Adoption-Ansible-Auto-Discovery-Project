locals {
  name = "petclinic"
}

module "vpc" {
  source = "./module/vpc"
  name = local.name
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