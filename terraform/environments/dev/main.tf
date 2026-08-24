locals {
  config = yamldecode(file("${path.module}/config.yaml"))
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = local.config.rg_name
  location = local.config.location
}

module "network" {
  source      = "../../modules/network"

  location    = local.config.location
  rg_name     = azurerm_resource_group.rg.name
  vnet_cidr   = local.config.network.vnet_cidr
  subnet_cidr = local.config.network.subnet_cidr
}

# Commented out — Log Analytics + Application Insights are not open source.
# Observability is Prometheus + Grafana + OTEL Collector only. See
# terraform/modules/observability/main.tf for the open-source replacement note.
# module "observability" {
#   source   = "../../modules/observability"
#
#   location = local.config.location
#   rg_name  = azurerm_resource_group.rg.name
# }

module "aks" {
  source           = "../../modules/aks"

  location         = local.config.location
  rg_name          = azurerm_resource_group.rg.name
  cluster_name     = local.config.aks.cluster_name
  vm_size          = local.config.aks.vm_size
  node_min         = local.config.aks.node_min
  node_max         = local.config.aks.node_max
  user_vm_size     = local.config.aks.user_vm_size
  user_node_min    = local.config.aks.user_node_min
  user_node_max    = local.config.aks.user_node_max
  subnet_id        = module.network.aks_subnet_id
  # log_analytics_id = module.observability.log_analytics_id  # commented out with module.observability above
  service_cidr     = local.config.aks.service_cidr
  dns_service_ip   = local.config.aks.dns_service_ip
}

module "cosmos" {
  source     = "../../modules/cosmos"

  location   = local.config.location
  rg_name    = azurerm_resource_group.rg.name
  name       = local.config.cosmos.name
  throughput = local.config.cosmos.throughput
}

module "servicebus" {
  source   = "../../modules/servicebus"

  location = local.config.location
  rg_name  = azurerm_resource_group.rg.name
  sku      = local.config.servicebus.sku
}

module "redis" {
  source   = "../../modules/redis"

  location        = local.config.location
  rg_name         = azurerm_resource_group.rg.name
  name            = local.config.redis.name
  aks_outbound_ip = local.config.redis.aks_outbound_ip
}

module "acr" {
  source = "../../modules/acr"

  location = local.config.location
  rg_name  = azurerm_resource_group.rg.name
  name     = local.config.acr.name
  sku      = local.config.acr.sku
}

module "keyvault" {
  source = "../../modules/keyvault"

  location  = local.config.location
  rg_name   = azurerm_resource_group.rg.name
  name      = local.config.keyvault.name
  tenant_id = data.azurerm_client_config.current.tenant_id

  # Same connection string shape as the manual `kubectl create secret` command
  # this replaces (see the old Step 5 in DevOps-README.md history).
  redis_connection_string = "${module.redis.redis_hostname}:${module.redis.redis_port},ssl=true,abortConnect=false,password=${module.redis.redis_primary_key}"
}

module "workload_identity" {
  source = "../../modules/workload-identity"

  location                       = local.config.location
  rg_name                        = azurerm_resource_group.rg.name
  oidc_issuer_url                = module.aks.oidc_issuer_url
  servicebus_namespace_id        = module.servicebus.namespace_id
  cosmos_account_id              = module.cosmos.account_id
  cosmos_account_name            = module.cosmos.account_name
  redis_id                       = module.redis.redis_id
  acr_id                         = module.acr.id
  aks_kubelet_identity_object_id = module.aks.kubelet_identity_object_id
  github_repo                    = local.config.github_repo
  keyvault_id                    = module.keyvault.id
}

# ── Cosmos DB seed ───────────────────────────────────────────────────────────
# Runs scripts/seed_cosmos.py after the products container is created (or
# recreated). The trigger ensures it re-runs if the container is destroyed and
# rebuilt, but is otherwise a no-op on subsequent applies (upserts are safe).
resource "null_resource" "seed_cosmos" {
  triggers = {
    container_id = module.cosmos.container_id
  }

  provisioner "local-exec" {
    command = "python ${path.module}/../../../scripts/seed_cosmos.py"

    environment = {
      COSMOS_ENDPOINT  = module.cosmos.endpoint
      COSMOS_DATABASE  = module.cosmos.database_name
      COSMOS_CONTAINER = module.cosmos.container_name
      PRODUCTS_JSON    = "${path.module}/../../../services/productcatalogservice/products.json"
    }
  }

  depends_on = [
    module.cosmos,
    module.workload_identity,
  ]
}

output "worker_client_ids" {
  description = "Managed Identity client IDs — paste into helm/workers/*/values.yaml"
  value       = module.workload_identity.client_ids
}

output "keda_operator_client_id" {
  description = "KEDA operator Managed Identity client ID — configure in KEDA ArgoCD app helm values"
  value       = module.workload_identity.keda_operator_client_id
}

output "cosmos_endpoint" {
  description = "Cosmos DB endpoint — use in productcatalogservice COSMOS_ENDPOINT env var"
  value       = module.cosmos.endpoint
}

output "cosmos_database" {
  description = "Cosmos DB database name"
  value       = module.cosmos.database_name
}

output "cosmos_container" {
  description = "Cosmos DB container name"
  value       = module.cosmos.container_name
}

output "redis_hostname" {
  description = "Redis hostname — part of REDIS_ADDR connection string"
  value       = module.redis.redis_hostname
}

# Commented out along with module.observability above.
# output "app_insights_connection_string" {
#   description = "Application Insights connection string — paste into kubernetes-platform/observability/app-insights/configmap.yaml"
#   value       = module.observability.app_insights_connection_string
#   sensitive   = true
# }

output "acr_login_server" {
  description = "ACR login server — set as the ACR_LOGIN_SERVER GitHub repo secret and used as the image prefix in kustomize overlays"
  value       = module.acr.login_server
}

output "acr_name" {
  description = "ACR name — set as the ACR_NAME GitHub repo secret (used by `az acr login`/`az acr build`)"
  value       = module.acr.name
}

output "github_actions_client_id" {
  description = "Set as the AZURE_CLIENT_ID GitHub repo secret"
  value       = module.workload_identity.github_actions_client_id
}

output "github_actions_tenant_id" {
  description = "Set as the AZURE_TENANT_ID GitHub repo secret"
  value       = module.workload_identity.github_actions_tenant_id
}

output "azure_subscription_id" {
  description = "Set as the AZURE_SUBSCRIPTION_ID GitHub repo secret"
  value       = data.azurerm_client_config.current.subscription_id
}

output "keyvault_name" {
  description = "Paste into kustomize/base/cartservice/secretproviderclass.yaml parameters.keyvaultName"
  value       = module.keyvault.name
}

output "azure_tenant_id" {
  description = "Paste into kustomize/base/cartservice/secretproviderclass.yaml parameters.tenantId"
  value       = data.azurerm_client_config.current.tenant_id
}
