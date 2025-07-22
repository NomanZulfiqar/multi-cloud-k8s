resource "azurerm_postgresql_flexible_server" "this" {
  name                = "aks-postgres-db"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  zone                = "1"  # Specify the zone to match existing resource
  
  lifecycle {
    ignore_changes = [
      zone,
      high_availability,
      storage_mb,
      administrator_login,
      administrator_password
    ]
  }

  sku_name   = "B_Standard_B1ms"
  storage_mb = 32768
  version    = "13"

  administrator_login    = "app_user"
  administrator_password = "app_password"  # Use Azure Key Vault in production

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
}

resource "azurerm_postgresql_flexible_server_database" "this" {
  name      = "app_database"
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "this" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"  # This allows Azure services only, not all IPs
}