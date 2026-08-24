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
