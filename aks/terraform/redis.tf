resource "azurerm_redis_cache" "this" {
  name                = "aks-redis-${formatdate("YYMMDDhhmmss", timestamp())}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  capacity            = 0
  family              = "C"
  sku_name            = "Basic"
  minimum_tls_version = "1.2"
  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }
}