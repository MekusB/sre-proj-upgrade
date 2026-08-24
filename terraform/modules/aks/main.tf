resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.rg_name
  dns_prefix          = var.cluster_name

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                        = "system"
    vm_size                     = var.vm_size
    vnet_subnet_id              = var.subnet_id
    auto_scaling_enabled        = true
    min_count                   = var.node_min
    max_count                   = var.node_max
    max_pods                    = 110
    # Allows azurerm to rotate the default pool to a new SKU without destroying
    # the cluster. Terraform creates a pool named "systtmp", drains & deletes
    # the old "system" pool, then removes the temp pool.
    temporary_name_for_rotation = "systtmp"
  }

  network_profile {
    network_plugin = "azure"
    service_cidr   = var.service_cidr
    dns_service_ip = var.dns_service_ip
  }

  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  # Installs the Secrets Store CSI Driver + Azure Key Vault provider. Pods use
  # their own workload identity (not this addon's identity) to authenticate to
  # Key Vault — see modules/workload-identity for the per-service RBAC grants.
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }
}

# User node pool — dedicated workload pool separate from system pool
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                  = "userpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.user_vm_size
  vnet_subnet_id        = var.subnet_id
  auto_scaling_enabled  = true
  min_count             = var.user_node_min
  max_count             = var.user_node_max
  max_pods              = 110
  mode                  = "User"

  depends_on = [azurerm_kubernetes_cluster.aks]
}

# Commented out — depended on the Log Analytics workspace (terraform/modules/
# observability), which is commented out for being non-open-source. AKS
# control-plane logs/metrics currently go nowhere; re-enable this (pointed at
# a workspace) or replace with an open-source equivalent if that's needed.
#
# resource "azurerm_monitor_diagnostic_setting" "aks" {
#   name                       = "aks-diagnostics"
#   target_resource_id         = azurerm_kubernetes_cluster.aks.id
#   log_analytics_workspace_id = var.log_analytics_id
#
#   enabled_log { category = "kube-apiserver" }
#   enabled_log { category = "kube-controller-manager" }
#   enabled_log { category = "kube-scheduler" }
#   enabled_log { category = "cluster-autoscaler" }
#
#   enabled_metric {
#   category = "AllMetrics"
#  }
# }
