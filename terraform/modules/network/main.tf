resource "azurerm_virtual_network" "vnet" {
  name                = "sre-vnet"
  address_space       = [var.vnet_cidr]
  location            = var.location
  resource_group_name = var.rg_name
}

resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  # /22 = 1022 usable IPs; required for Azure CNI with 11+ microservices
  # each pod gets its own IP from this subnet
  address_prefixes = [var.subnet_cidr]

  depends_on = [azurerm_virtual_network.vnet]
}
