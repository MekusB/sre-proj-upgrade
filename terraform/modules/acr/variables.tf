variable "location" {
  type = string
}

variable "rg_name" {
  type = string
}

variable "name" {
  type        = string
  description = "Globally-unique ACR name (alphanumeric only, 5-50 chars)."
}

variable "sku" {
  type    = string
  default = "Basic"
}
