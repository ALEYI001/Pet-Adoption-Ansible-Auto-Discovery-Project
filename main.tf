locals {
  name = "petclinic"
}

module "vpc" {
  source = "./module/vpc"
  name = local.name
}
module "name" {
  source = "./module/bastion"
  name = local.name
  vpc         = module.vpc.vpc_id
  subnets     = module.vpc.public_subnets
  private_key = module.vpc.private_key_pem  # sensitive
}