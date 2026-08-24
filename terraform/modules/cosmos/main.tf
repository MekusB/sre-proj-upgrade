resource "azurerm_cosmosdb_account" "cosmos" {
  name                = var.name
  location            = var.location
  resource_group_name = var.rg_name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
    zone_redundant    = false
  }
}

resource "azurerm_cosmosdb_sql_database" "product_catalog" {
  name                = "product-catalog-db"
  resource_group_name = var.rg_name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  throughput          = var.throughput
}

resource "azurerm_cosmosdb_sql_container" "products" {
  name                = "products"
  resource_group_name = var.rg_name
  account_name        = azurerm_cosmosdb_account.cosmos.name
  database_name       = azurerm_cosmosdb_sql_database.product_catalog.name
  partition_key_paths = ["/id"]
}
