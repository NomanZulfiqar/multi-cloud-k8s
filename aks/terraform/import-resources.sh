#!/bin/bash
set -e

# Initialize Terraform
terraform init

# Function to check if a resource exists in Azure
resource_exists_in_azure() {
  local resource_type=$1
  local resource_name=$2
  local resource_group=$3
  
  case "$resource_type" in
    "resource_group")
      az group show --name "$resource_name" &>/dev/null
      return $?
      ;;
    "vnet")
      az network vnet show --name "$resource_name" --resource-group "$resource_group" &>/dev/null
      return $?
      ;;
    "subnet")
      az network vnet subnet show --name "$resource_name" --vnet-name "$2" --resource-group "$resource_group" &>/dev/null
      return $?
      ;;
    "aks")
      az aks show --name "$resource_name" --resource-group "$resource_group" &>/dev/null
      return $?
      ;;
    *)
      return 1
      ;;
  esac
}

# Function to check if a resource is already in the state
resource_exists_in_state() {
  local resource_type=$1
  local resource_name=$2
  terraform state list | grep -q "${resource_type}.${resource_name}"
  return $?
}

# Check if resource group exists before trying to import
echo "Checking resource group..."
if resource_exists_in_azure "resource_group" "aks-resource-group"; then
  if ! resource_exists_in_state "azurerm_resource_group" "this"; then
    echo "Importing resource group..."
    terraform import azurerm_resource_group.this /subscriptions/1fbbd390-f113-419c-aa71-2c00b9564acb/resourceGroups/aks-resource-group
  else
    echo "Resource group already in state, skipping import"
  fi
else
  echo "Resource group doesn't exist in Azure, will be created"
fi

# Only check for other resources if resource group exists
if resource_exists_in_azure "resource_group" "aks-resource-group"; then
  # Import virtual network (if it exists)
  echo "Checking virtual network..."
  if resource_exists_in_azure "vnet" "aks-vnet" "aks-resource-group"; then
    if ! resource_exists_in_state "azurerm_virtual_network" "this"; then
      echo "Importing virtual network..."
      terraform import azurerm_virtual_network.this /subscriptions/1fbbd390-f113-419c-aa71-2c00b9564acb/resourceGroups/aks-resource-group/providers/Microsoft.Network/virtualNetworks/aks-vnet
    else
      echo "Virtual network already in state, skipping import"
    fi
  else
    echo "Virtual network doesn't exist in Azure, will be created"
  fi

  # Import subnet (if it exists)
  echo "Checking subnet..."
  if resource_exists_in_azure "subnet" "aks-subnet" "aks-vnet" "aks-resource-group"; then
    if ! resource_exists_in_state "azurerm_subnet" "this"; then
      echo "Importing subnet..."
      terraform import azurerm_subnet.this /subscriptions/1fbbd390-f113-419c-aa71-2c00b9564acb/resourceGroups/aks-resource-group/providers/Microsoft.Network/virtualNetworks/aks-vnet/subnets/aks-subnet
    else
      echo "Subnet already in state, skipping import"
    fi
  else
    echo "Subnet doesn't exist in Azure, will be created"
  fi

  # Import AKS cluster (if it exists)
  echo "Checking AKS cluster..."
  if resource_exists_in_azure "aks" "aks-cluster" "aks-resource-group"; then
    if ! resource_exists_in_state "azurerm_kubernetes_cluster" "this"; then
      echo "Importing AKS cluster..."
      terraform import azurerm_kubernetes_cluster.this /subscriptions/1fbbd390-f113-419c-aa71-2c00b9564acb/resourceGroups/aks-resource-group/providers/Microsoft.ContainerService/managedClusters/aks-cluster
    else
      echo "AKS cluster already in state, skipping import"
    fi
  else
    echo "AKS cluster doesn't exist in Azure, will be created"
  fi

  # Import Redis cache (if it exists)
  echo "Checking Redis cache..."
  REDIS_NAME=$(az redis list --resource-group aks-resource-group --query "[0].name" -o tsv 2>/dev/null || echo "")
  if [ -n "$REDIS_NAME" ]; then
    if ! resource_exists_in_state "azurerm_redis_cache" "this"; then
      echo "Importing Redis cache..."
      terraform import azurerm_redis_cache.this /subscriptions/1fbbd390-f113-419c-aa71-2c00b9564acb/resourceGroups/aks-resource-group/providers/Microsoft.Cache/redis/$REDIS_NAME
    else
      echo "Redis cache already in state, skipping import"
    fi
  else
    echo "Redis cache doesn't exist in Azure, will be created"
  fi

  # Import PostgreSQL flexible server (if it exists)
  echo "Checking PostgreSQL flexible server..."
  POSTGRES_NAME=$(az postgres flexible-server list --resource-group aks-resource-group --query "[0].name" -o tsv 2>/dev/null || echo "")
  if [ -n "$POSTGRES_NAME" ]; then
    if ! resource_exists_in_state "azurerm_postgresql_flexible_server" "this"; then
      echo "Importing PostgreSQL flexible server..."
      terraform import azurerm_postgresql_flexible_server.this /subscriptions/1fbbd390-f113-419c-aa71-2c00b9564acb/resourceGroups/aks-resource-group/providers/Microsoft.DBforPostgreSQL/flexibleServers/$POSTGRES_NAME
    else
      echo "PostgreSQL flexible server already in state, skipping import"
    fi
  else
    echo "PostgreSQL flexible server doesn't exist in Azure, will be created"
  fi
fi

echo "Import check complete. Now you can run terraform plan/apply."