resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  
  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
  
  lifecycle {
    prevent_destroy = false
  }
}

resource "azurerm_virtual_network" "this" {
  name                = "aks-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_subnet" "this" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = var.cluster_name
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name           = "default"
    node_count     = var.node_count
    vm_size        = var.vm_size
    vnet_subnet_id = azurerm_subnet.this.id
    os_sku         = "Mariner"  # Using CBL-Mariner (Microsoft's Linux distribution)
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = "172.16.0.0/16"  # Changed to avoid overlap with VNet CIDR
    dns_service_ip    = "172.16.0.10"    # Must be within service_cidr
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
  
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      kubernetes_version,
      default_node_pool[0].node_count,
      network_profile,
      default_node_pool[0].vm_size,
      tags
    ]
  }
}