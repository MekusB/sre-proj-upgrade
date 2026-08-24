output "cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}

output "node_resource_group" {
  value = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet managed identity — grant this AcrPull on any registry AKS needs to pull images from."
  value       = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
