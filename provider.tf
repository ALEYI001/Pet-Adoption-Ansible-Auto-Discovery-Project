provider "aws" {
  region  = "us-east-1"
  # profile = "pet_team"
}

provider "vault" {
  address = "https://vault.work-experience2025.buzz"
  token   = var.vault_token
}

data "vault_generic_secret" "secrets" {
  path = "secret/database"
}

terraform {
  backend "s3" {
    bucket       = "adoptionteam1-bucket"
    key          = "infra/terraform.tfstate"
    region       = "us-east-1"
    # profile      = "pet_team"
    encrypt      = true
    use_lockfile = true
  }
}