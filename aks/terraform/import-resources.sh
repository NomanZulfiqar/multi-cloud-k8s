#!/bin/bash
set -e

# Initialize Terraform
terraform init

# Function to check if a resource is already in the state
resource_exists_in_state() {
  local resource_type=$1
  local resource_name=$2
  terraform state list | grep -q "${resource_type}.${resource_name}"
  return $?
}

# Import resource group if not already in state
echo "Checking resource group..."
if ! resource_exists_in_state "azurerm_resource_group" "this"; then
  echo "Importing resource group..."
  terraform import azurerm_resource_group.this /subscriptions/1fbbd390-f113-419c-aa71-2c00b9564acb/resourceGroups/aks-resource-group
else
  echo "Resource group already in state, skipping import"
fi

# Import virtual network (if it exists and not in state)
echo "Checking virtual network..."
if ! resource_exists_in_state "azurerm_virtual_network" "this"; then
  echo "Importing virtual network..."
  terraform import azurerm_virtual_network.this /subscriptions/1fbbd390-f113-419c-aa71-2c00b9564acb/resourceGroups/aks-resource-group/providers/Microsoft.Network/virtualNetworks/aks-vnet || echo "Virtual network not found, will be created"
else
  echo "Virtual network already in state, skipping import"
fi

# Import subnet (if it exists and not in state)
echo "Checking subnet..."
if ! resource_exists_in_state "azurerm_subnet" "this"; then
  echo "Importing subnet..."
  terraform import azurerm_subnet.this /subscriptions/1fbbd390-f113-419c-aa71-2c00b9564acb/resourceGroups/aks-resource-group/providers/Microsoft.Network/virtualNetworks/aks-vnet/subnets/aks-subnet || echo "Subnet not found, will be created"
else
  echo "Subnet already in state, skipping import"
fi

# Import AKS cluster (if it exists and not in state)
echo "Checking AKS cluster..."
if ! resource_exists_in_state "azurerm_kubernetes_cluster" "this"; then
  echo "Importing AKS cluster..."
  terraform import azurerm_kubernetes_cluster.this /subscriptions/1fbbd390-f113-419c-aa71-2c00b9564acb/resourceGroups/aks-resource-group/providers/Microsoft.ContainerService/managedClusters/aks-cluster || echo "AKS cluster not found, will be created"
else
  echo "AKS cluster already in state, skipping import"
fi

# Import Redis cache (if it exists and not in state)
echo "Checking Redis cache..."
if ! resource_exists_in_state "azurerm_redis_cache" "this"; then
  echo "Importing Redis cache..."
  # Get the actual name of the Redis cache
  REDIS_NAME=$(az redis list --resource-group aks-resource-group --query "[0].name" -o tsv 2>/dev/null || echo "")
  if [ -n "$REDIS_NAME" ]; then
    terraform import azurerm_redis_cache.this /subscriptions/1fbbd390-f113-419c-aa71-2c00b9564acb/resourceGroups/aks-resource-group/providers/Microsoft.Cache/redis/$REDIS_NAME
  else
    echo "Redis cache not found, will be created"
  fi
else
  echo "Redis cache already in state, skipping import"
fi

# Import PostgreSQL flexible server (if it exists and not in state)
echo "Checking PostgreSQL flexible server..."
if ! resource_exists_in_state "azurerm_postgresql_flexible_server" "this"; then
  echo "Importing PostgreSQL flexible server..."
  # Get the actual name of the PostgreSQL server
  POSTGRES_NAME=$(az postgres flexible-server list --resource-group aks-resource-group --query "[0].name" -o tsv 2>/dev/null || echo "")
  if [ -n "$POSTGRES_NAME" ]; then
    terraform import azurerm_postgresql_flexible_server.this /subscriptions/1fbbd390-f113-419c-aa71-2c00b9564acb/resourceGroups/aks-resource-group/providers/Microsoft.DBforPostgreSQL/flexibleServers/$POSTGRES_NAME
  else
    echo "PostgreSQL flexible server not found, will be created"
  fi
else
  echo "PostgreSQL flexible server already in state, skipping import"
fi

echo "Import complete. Now you can run terraform plan/apply."