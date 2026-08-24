variable "location" {
  type = string
}

variable "rg_name" {
  type = string
}

variable "name" {
  type        = string
  description = "Cosmos DB account name — must be globally unique across Azure (lowercase letters, numbers, hyphens, 3-44 chars)"
}

variable "throughput" {
  type    = number
  default = 4000
}
