variable "location" {
  type = string
}

variable "rg_name" {
  type = string
}

variable "oidc_issuer_url" {
  type        = string
  description = "OIDC issuer URL from the AKS cluster"
}

variable "servicebus_namespace_id" {
  type        = string
  description = "Resource ID of the Service Bus namespace"
}

variable "workers" {
  type        = list(string)
  description = "List of worker names to create identities for"
  default = [
    "adservice-worker",
    "cartservice-worker",
    "checkoutservice-worker",
    "currencyservice-worker",
    "emailservice-worker",
    "paymentservice-worker",
    "productcatalogservice-worker",
    "recommendationservice-worker",
    "shippingservice-worker",
    "shoppingassistantservice-worker"
  ]
}

variable "k8s_namespace" {
  type        = string
  description = "Kubernetes namespace where worker ServiceAccounts live"
  default     = "workers"
}

variable "keda_namespace" {
  type        = string
  description = "Kubernetes namespace where KEDA operator ServiceAccount lives"
  default     = "keda"
}

variable "cosmos_account_id" {
  type        = string
  description = "Resource ID of the Cosmos DB account"
}

variable "cosmos_account_name" {
  type        = string
  description = "Name of the Cosmos DB account (used for SQL role assignments)"
}

variable "redis_id" {
  type        = string
  description = "Resource ID of the Azure Cache for Redis instance"
}

variable "acr_id" {
  type        = string
  description = "Resource ID of the Azure Container Registry"
}

variable "aks_kubelet_identity_object_id" {
  type        = string
  description = "Object ID of the AKS kubelet managed identity — granted AcrPull on the registry"
}

variable "github_repo" {
  type        = string
  description = "GitHub repo in <org>/<repo> form, used to scope the OIDC federated credential subject"
}

variable "github_ref" {
  type        = string
  description = "Git ref CI is allowed to authenticate from"
  default     = "refs/heads/main"
}

variable "keyvault_id" {
  type        = string
  description = "Resource ID of the Key Vault holding the Redis connection string"
}

variable "deployer_object_id" {
  type        = string
  description = "Object ID of the identity running `terraform apply` — granted Cosmos DB Built-in Data Contributor so the seed_cosmos.py local-exec provisioner can write the product catalog. Cosmos DB RBAC is data-plane and separate from Azure RBAC; nothing else grants the deployer access to it."
}
