locals {
  name = "petclinic"
}

module "vpc" {
  source = "./module/vpc"
  name = local.name
}

module "nexus" {
  source             = "./module/nexus"
  name               = local.name
  vpc_id             = module.vpc.vpc_id
  subnet_id         = module.vpc.pub-sub1_id
  subnet_ids        = [module.vpc.pub-sub1_id, module.vpc.pub-sub2_id]
  key_pair_name      = module.vpc.key_pair_name
  domain_name        = var.domain_name
  newrelic_api_key   = var.newrelic_api_key 
  newrelic_account_id = var.newrelic_account_id
}