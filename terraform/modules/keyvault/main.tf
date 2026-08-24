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

# RBAC-enabled vaults grant nobody by default — not even the identity running
# `terraform apply`. Without this, azurerm_key_vault_secret below 403s: the
# deploying principal has no data-plane permission to write secrets.
resource "azurerm_role_assignment" "deployer_secrets_officer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.deployer_object_id
}

# Azure RBAC assignments take a little while to propagate; writing the secret
# immediately after the role assignment reliably 403s otherwise.
resource "time_sleep" "wait_for_rbac" {
  depends_on      = [azurerm_role_assignment.deployer_secrets_officer]
  create_duration = "60s"
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

  depends_on = [time_sleep.wait_for_rbac]
}
