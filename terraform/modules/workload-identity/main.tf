#  User Assigned Managed Identity per worker 
resource "azurerm_user_assigned_identity" "worker" {
  for_each = toset(var.workers)

  name                = each.key
  location            = var.location
  resource_group_name = var.rg_name
}

#  Federated Identity Credential (workload pod) 
# Links each worker K8s ServiceAccount to its Managed Identity via OIDC
resource "azurerm_federated_identity_credential" "worker" {
  for_each = toset(var.workers)

  name                      = each.key
  user_assigned_identity_id = azurerm_user_assigned_identity.worker[each.key].id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.oidc_issuer_url
  subject                   = "system:serviceaccount:${var.k8s_namespace}:${each.key}-sa"
}

resource "azurerm_federated_identity_credential" "checkoutservice_core" {
  name                      = "checkoutservice-core"
  user_assigned_identity_id = azurerm_user_assigned_identity.worker["checkoutservice-worker"].id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.oidc_issuer_url
  subject                   = "system:serviceaccount:core:checkoutservice-sa"
}

# Federated Identity Credential (KEDA operator override)
# When TriggerAuthentication uses identityId to override, KEDA presents the
# keda-operator SA token — so each worker identity needs a federated credential
# trusting system:serviceaccount:keda:keda-operator as well.
resource "azurerm_federated_identity_credential" "keda_override" {
  for_each = toset(var.workers)

  name                      = "${each.key}-keda-override"
  user_assigned_identity_id = azurerm_user_assigned_identity.worker[each.key].id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.oidc_issuer_url
  subject                   = "system:serviceaccount:${var.keda_namespace}:keda-operator"
}

#  Service Bus RBAC 
# Grants each worker identity permission to read from Service Bus
resource "azurerm_role_assignment" "servicebus_receiver" {
  for_each = toset(var.workers)

  scope                = var.servicebus_namespace_id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_user_assigned_identity.worker[each.key].principal_id
}

resource "azurerm_role_assignment" "checkoutservice_servicebus_sender" {
  scope                = var.servicebus_namespace_id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_user_assigned_identity.worker["checkoutservice-worker"].principal_id
}

# ─── KEDA Operator Identity ───────────────────────────────────────────────────
# KEDA's operator pod itself needs workload identity to call Azure Service Bus
# metrics APIs on behalf of the TriggerAuthentication resources.

resource "azurerm_user_assigned_identity" "keda_operator" {
  name                = "keda-operator"
  location            = var.location
  resource_group_name = var.rg_name
}

resource "azurerm_federated_identity_credential" "keda_operator" {
  name                      = "keda-operator"
  user_assigned_identity_id = azurerm_user_assigned_identity.keda_operator.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.oidc_issuer_url
  subject                   = "system:serviceaccount:${var.keda_namespace}:keda-operator"
}

resource "azurerm_role_assignment" "keda_servicebus_receiver" {
  scope                = var.servicebus_namespace_id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_user_assigned_identity.keda_operator.principal_id
}

# ─── Core Service Identities ──────────────────────────────────────────────────
# cartservice and productcatalogservice run in the `core` namespace and need
# their own federated credentials bound to their Managed Identities
# (reusing the worker identities already created above).

resource "azurerm_federated_identity_credential" "cartservice_core" {
  name                      = "cartservice-core"
  user_assigned_identity_id = azurerm_user_assigned_identity.worker["cartservice-worker"].id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.oidc_issuer_url
  subject                   = "system:serviceaccount:core:cartservice-sa"
}

resource "azurerm_federated_identity_credential" "productcatalogservice_core" {
  name                      = "productcatalogservice-core"
  user_assigned_identity_id = azurerm_user_assigned_identity.worker["productcatalogservice-worker"].id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.oidc_issuer_url
  subject                   = "system:serviceaccount:core:productcatalogservice-sa"
}

# ─── Cosmos DB RBAC ───────────────────────────────────────────────────────────
# Grants productcatalogservice the built-in Cosmos DB Data Contributor role
# so it can read/write documents via DefaultAzureCredential (Workload Identity).

resource "azurerm_cosmosdb_sql_role_assignment" "productcatalog_data_contributor" {
  resource_group_name = var.rg_name
  account_name        = var.cosmos_account_name
  role_definition_id  = "${var.cosmos_account_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = azurerm_user_assigned_identity.worker["productcatalogservice-worker"].principal_id
  scope               = var.cosmos_account_id
}

# Cosmos DB RBAC is data-plane and separate from Azure RBAC — creating the
# account grants nobody data access, not even the identity running
# `terraform apply`. Without this, null_resource.seed_cosmos 403s trying to
# read/write the products container.
resource "azurerm_cosmosdb_sql_role_assignment" "deployer_data_contributor" {
  resource_group_name = var.rg_name
  account_name        = var.cosmos_account_name
  role_definition_id  = "${var.cosmos_account_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        = var.deployer_object_id
  scope               = var.cosmos_account_id
}

# Cosmos DB RBAC assignments take a little while to propagate; seeding
# immediately after tends to 403 otherwise.
resource "time_sleep" "wait_for_cosmos_rbac" {
  depends_on      = [azurerm_cosmosdb_sql_role_assignment.deployer_data_contributor]
  create_duration = "90s"
}

# ─── Redis IAM ────────────────────────────────────────────────────────────────
# cartservice authenticates to Redis using a connection string (access key),
# not Azure RBAC — Azure Cache for Redis data-plane access is key-based, not
# identity-based. What IS identity-based is how that connection string reaches
# the pod: cartservice's workload identity reads it out of Key Vault via the
# CSI driver (see the role assignment below), instead of a manually-created
# Kubernetes Secret.

resource "azurerm_role_assignment" "cartservice_keyvault_secrets_user" {
  scope                = var.keyvault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.worker["cartservice-worker"].principal_id
}

# ─── AKS → ACR pull ────────────────────────────────────────────────────────────
# Lets every node pool's kubelet identity pull images from the registry without
# an imagePullSecret (equivalent to `az aks update --attach-acr`).

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = var.aks_kubelet_identity_object_id
}

# ─── GitHub Actions → ACR push (OIDC, no stored credentials) ──────────────────
# CI authenticates as this identity via azure/login's OIDC federation — no
# client secret or registry password stored in GitHub. Trust is scoped to a
# single repo and ref, so a workflow run on another repo/branch can't assume it.

resource "azurerm_user_assigned_identity" "github_actions" {
  name                = "github-actions-ci"
  location            = var.location
  resource_group_name = var.rg_name
}

resource "azurerm_federated_identity_credential" "github_actions" {
  name                      = "github-actions-ci"
  user_assigned_identity_id = azurerm_user_assigned_identity.github_actions.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:${var.github_repo}:ref:${var.github_ref}"
}

resource "azurerm_role_assignment" "github_actions_acr_push" {
  scope                = var.acr_id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.github_actions.principal_id
}
