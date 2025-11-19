variable "name" {}
variable "vpc_id" {}
variable "subnet_id" { type = list(string) }
variable "keypair_name" {}
variable "private_key" {}
variable "newrelic_api_key" {}
variable "newrelic_account_id" {}   
variable "s3_bucket_name" {} 
variable "nexus_ip" {} 