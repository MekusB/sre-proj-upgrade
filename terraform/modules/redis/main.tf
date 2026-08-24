resource "azurerm_redis_cache" "redis" {
  name                = var.name
  location            = var.location
  resource_group_name = var.rg_name
  capacity            = 1
  family              = "C"
  sku_name            = "Standard"

  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }

  minimum_tls_version = "1.2"
}

# Azure Cache for Redis does NOT support VNet service endpoints, so pod traffic
# exits via the AKS cluster's outbound NAT public IP — not the private subnet range.
# The aks_egress rule is the one that actually grants access.
# The aks_pods rule (private range) is kept as a no-op placeholder in case
# service endpoint support is added in future, but it has no effect today.
resource "azurerm_redis_firewall_rule" "aks_subnet" {
  name                = "allow_aks_pods"
  redis_cache_name    = azurerm_redis_cache.redis.name
  resource_group_name = var.rg_name
  start_ip            = "10.0.0.0"
  end_ip              = "10.0.3.255"
}

resource "azurerm_redis_firewall_rule" "aks_egress" {
  name                = "allow_aks_egress"
  redis_cache_name    = azurerm_redis_cache.redis.name
  resource_group_name = var.rg_name
  start_ip            = var.aks_outbound_ip
  end_ip              = var.aks_outbound_ip
}
