variable "location" {
  type = string
}

variable "rg_name" {
  type = string
}

variable "name" {
  type        = string
  description = "Globally-unique Key Vault name (alphanumeric + hyphens, 3-24 chars)."
}

variable "tenant_id" {
  type = string
}

variable "redis_connection_string" {
  type      = string
  sensitive = true
}

variable "deployer_object_id" {
  type        = string
  description = "Object ID of the identity running `terraform apply` — granted Key Vault Secrets Officer so it can write the initial secret (RBAC-enabled vaults grant nobody by default)."
}
