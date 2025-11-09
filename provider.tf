provider "aws" {
  region = "us-east-1"
  profile = "pet_team"
}

# terraform {
#   backend "s3" {
#     bucket       = "adoptionteam1-bucket"
#     key          = "infra/terraform.tfstate"
#     region       = "us-east-1"
#     profile      = "pet_team"
#     encrypt      = true
#     use_lockfile = true
#   }
# }