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
module "database" {
  source      = "./module/database"
  name        = local.name
  db_subnets  = [module.vpc.private_subnet_ids[0], module.vpc.private_subnet_ids[1]]
  vpc_id      = module.vpc.vpc_id
  stage_sg    = module.prod.prod_sg
  prod_sg     = module.stage.stage_sg
  db_username = data.vault_generic_secret.database.data["username"]
  db_password = data.vault_generic_secret.database.data["password"]
}