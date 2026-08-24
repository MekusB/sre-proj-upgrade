resource "azurerm_container_registry" "acr" {
  name                = var.name
  resource_group_name = var.rg_name
  location            = var.location
  sku                 = var.sku

  # No admin username/password — CI authenticates via OIDC federated identity
  # (see workload-identity module) and in-cluster pulls use the AKS kubelet
  # managed identity. Zero static registry credentials.
  admin_enabled = false
}
