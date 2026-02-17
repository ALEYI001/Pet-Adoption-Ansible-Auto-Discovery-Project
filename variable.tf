variable "newrelic_api_key" {
  description = "New Relic API key"
  type        = string
  default     = "NRAK-HM7WE8XXY3PAZR5LBG2AHC22PYH"
}

variable "vault_token" {
  description = "Vault token for accessing secrets"
  type        = string
  default     = "hvs.ZMtfPX90cV7eQMbKq3RflhPi"
}

variable "newrelic_account_id" {
  description = "New Relic account id (optional)"
  type        = string
  default     = "7233367"
}

variable "domain_name" {
  description = "The domain name for the project"
  type        = string
  default     = "aleyi.space"
}

variable "s3_bucket_name" {
  description = "S3 bucket name for storing Ansible playbooks"
  type        = string
  default     = "adoptionteam1-bucket2"
}
