variable "location" {
  type = string
}

variable "rg_name" {
  type = string
}

variable "name" {
  type        = string
  description = "Redis cache name — must be globally unique across Azure (alphanumeric + hyphens, 1-63 chars, forms <name>.redis.cache.windows.net)"
}

variable "aks_outbound_ip" {
  type        = string
  description = "AKS cluster outbound NAT public IP. Pods reach Redis through this IP since Azure Cache for Redis does not support VNet service endpoints."
}
