#!/bin/bash
set -e

# Initialize Terraform
terraform init

# Import resource group
echo "Importing resource group..."
terraform import azurerm_resource_group.this /subscriptions/1fbbd390-f113-419c-aa71-2c00b9564acb/resourceGroups/aks-resource-group

# Import virtual network (if it exists)
echo "Importing virtual network..."
terraform import azurerm_virtual_network.this /subscriptions/1fbbd390-f113-419c-aa71-2c00b9564acb/resourceGroups/aks-resource-group/providers/Microsoft.Network/virtualNetworks/aks-vnet || echo "Virtual network not found, will be created"

# Import subnet (if it exists)
echo "Importing subnet..."
terraform import azurerm_subnet.this /subscriptions/1fbbd390-f113-419c-aa71-2c00b9564acb/resourceGroups/aks-resource-group/providers/Microsoft.Network/virtualNetworks/aks-vnet/subnets/aks-subnet || echo "Subnet not found, will be created"

# Import AKS cluster (if it exists)
echo "Importing AKS cluster..."
terraform import azurerm_kubernetes_cluster.this /subscriptions/1fbbd390-f113-419c-aa71-2c00b9564acb/resourceGroups/aks-resource-group/providers/Microsoft.ContainerService/managedClusters/aks-cluster || echo "AKS cluster not found, will be created"

# Import Redis cache (if it exists)
echo "Importing Redis cache..."
terraform import azurerm_redis_cache.this /subscriptions/1fbbd390-f113-419c-aa71-2c00b9564acb/resourceGroups/aks-resource-group/providers/Microsoft.Cache/redis/aks-redis-250722145327 || echo "Redis cache not found, will be created"

# Import PostgreSQL flexible server (if it exists)
echo "Importing PostgreSQL flexible server..."
# Get the actual name of the PostgreSQL server
POSTGRES_NAME=$(az postgres flexible-server list --resource-group aks-resource-group --query "[0].name" -o tsv 2>/dev/null || echo "")
if [ -n "$POSTGRES_NAME" ]; then
  terraform import azurerm_postgresql_flexible_server.this /subscriptions/1fbbd390-f113-419c-aa71-2c00b9564acb/resourceGroups/aks-resource-group/providers/Microsoft.DBforPostgreSQL/flexibleServers/$POSTGRES_NAME
else
  echo "PostgreSQL flexible server not found, will be created"
fi

echo "Import complete. Now you can run terraform plan/apply."