# Commented out — not open source. Observability stack is now Prometheus +
# Grafana + OTEL Collector only (see kubernetes-platform/observability/).
# If AKS control-plane diagnostics or a hosted trace/log backend are needed
# again, the open-source path is typically Loki (logs) + Tempo (traces),
# both of which the existing OTEL Collector can export to directly.

# resource "azurerm_log_analytics_workspace" "law" {
#   name                = "sre-law"
#   location            = var.location
#   resource_group_name = var.rg_name
#   sku                 = "PerGB2018"
# }

# resource "azurerm_application_insights" "appi" {
#   name                = "sre-appinsights"
#   location            = var.location
#   resource_group_name = var.rg_name
#   application_type    = "web"
#   workspace_id        = azurerm_log_analytics_workspace.law.id
# }
