resource "azurerm_redis_cache" "this" {
  name                = "aks-redis-cache"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      redis_configuration,
      capacity,
      family,
      sku_name
    ]
  }
  capacity            = 0
  family              = "C"
  sku_name            = "Basic"
  minimum_tls_version = "1.2"
  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }
}