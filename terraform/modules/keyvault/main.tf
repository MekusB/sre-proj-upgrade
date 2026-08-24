resource "azurerm_key_vault" "kv" {
  name                = var.name
  location            = var.location
  resource_group_name = var.rg_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  # RBAC instead of legacy access policies — grants are Azure role assignments
  # (see modules/workload-identity), same model as every other resource here.
  rbac_authorization_enabled = true
}

# Redis connection string — the one secret this repo previously created by
# hand with `kubectl create secret`. Now it's provisioned by Terraform and
# synced into the cluster by the Key Vault CSI driver (see
# kustomize/base/cartservice/secretproviderclass.yaml), so there's no manual,
# undocumented step between `terraform apply` and a working cartservice.
resource "azurerm_key_vault_secret" "redis_connection_string" {
  name         = "redis-connection-string"
  value        = var.redis_connection_string
  key_vault_id = azurerm_key_vault.kv.id
}
