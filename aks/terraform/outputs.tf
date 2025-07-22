output "kubernetes_cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.this.kube_config.0.client_certificate
  sensitive = true
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive = true
}

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "postgresql_server_name" {
  value = azurerm_postgresql_server.this.name
}

output "postgresql_server_fqdn" {
  value = azurerm_postgresql_server.this.fqdn
}

output "redis_hostname" {
  value = azurerm_redis_cache.this.hostname
}

output "redis_port" {
  value = azurerm_redis_cache.this.port
}

output "redis_primary_key" {
  value     = azurerm_redis_cache.this.primary_access_key
  sensitive = true
}