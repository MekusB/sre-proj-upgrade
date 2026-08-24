output "client_ids" {
  description = "Map of worker name to Managed Identity client ID"
  value = {
    for name, identity in azurerm_user_assigned_identity.worker :
    name => identity.client_id
  }
}

output "principal_ids" {
  description = "Map of worker name to Managed Identity principal ID"
  value = {
    for name, identity in azurerm_user_assigned_identity.worker :
    name => identity.principal_id
  }
}

output "keda_operator_client_id" {
  description = "Client ID of the KEDA operator Managed Identity"
  value       = azurerm_user_assigned_identity.keda_operator.client_id
}

output "github_actions_client_id" {
  description = "Client ID of the GitHub Actions CI Managed Identity — set as the AZURE_CLIENT_ID repo secret"
  value       = azurerm_user_assigned_identity.github_actions.client_id
}

output "github_actions_tenant_id" {
  description = "Tenant ID for the GitHub Actions CI Managed Identity — set as the AZURE_TENANT_ID repo secret"
  value       = azurerm_user_assigned_identity.github_actions.tenant_id
}
