terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  
  backend "s3" {
    bucket         = "noman-rocket-zulfiqar-terraform-backend-us-east-1"
    key            = "aks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "noman-rocket-zulfiqar-terraform-backend-us-east-1.lock"
    encrypt        = true
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "aks-rg"
  location = "East US"
}

# Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "myappacr2024"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Azure Key Vault
resource "azurerm_key_vault" "kv" {
  name                = "myapp-kv-2024"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover",
      "Backup",
      "Restore"
    ]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id

    secret_permissions = [
      "Get",
      "List"
    ]
  }
}

# Key Vault Secret
resource "azurerm_key_vault_secret" "db_username" {
  name         = "db-username"
  value        = "app_user"
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = "app_password"
  key_vault_id = azurerm_key_vault.kv.id
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "my-aks-cluster"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "myakscluster"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B2s"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "kubenet"
  }
}

# Note: ACR integration will be handled via attach-acr command in pipeline

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "postgres" {
  name                   = "myapp-postgres-2024"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "13"
  administrator_login    = "app_user"
  administrator_password = "app_password"
  
  storage_mb = 32768
  sku_name   = "B_Standard_B1ms"
  
  backup_retention_days = 7
}

resource "azurerm_postgresql_flexible_server_database" "app_db" {
  name      = "app_database"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_all" {
  name             = "allow-all"
  server_id        = azurerm_postgresql_flexible_server.postgres.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# Redis Cache
resource "azurerm_redis_cache" "redis" {
  name                = "myapp-redis-2024"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  capacity            = 0
  family              = "C"
  sku_name            = "Basic"
  non_ssl_port_enabled = true
  minimum_tls_version = "1.2"
}

data "azurerm_client_config" "current" {}

# Outputs
output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "key_vault_name" {
  value = azurerm_key_vault.kv.name
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.postgres.fqdn
}

output "redis_hostname" {
  value = azurerm_redis_cache.redis.hostname
}