#!/bin/bash

echo "Importing existing AKS resources if they exist..."

# Import Resource Group
if az group show --name "aks-rg" &>/dev/null; then
    echo "Importing resource group..."
    terraform import azurerm_resource_group.main /subscriptions/$(az account show --query id -o tsv)/resourceGroups/aks-rg || echo "Import failed, continuing"
fi

# Import ACR
if az acr show --name "myappacr2024" &>/dev/null; then
    echo "Importing ACR..."
    terraform import azurerm_container_registry.acr /subscriptions/$(az account show --query id -o tsv)/resourceGroups/aks-rg/providers/Microsoft.ContainerRegistry/registries/myappacr2024 || echo "Import failed, continuing"
fi

# Import Key Vault
if az keyvault show --name "myapp-kv-2024" &>/dev/null; then
    echo "Importing Key Vault..."
    terraform import azurerm_key_vault.kv /subscriptions/$(az account show --query id -o tsv)/resourceGroups/aks-rg/providers/Microsoft.KeyVault/vaults/myapp-kv-2024 || echo "Import failed, continuing"
fi

# Import AKS Cluster
if az aks show --name "my-aks-cluster" --resource-group "aks-rg" &>/dev/null; then
    echo "Importing AKS cluster..."
    terraform import azurerm_kubernetes_cluster.aks /subscriptions/$(az account show --query id -o tsv)/resourceGroups/aks-rg/providers/Microsoft.ContainerService/managedClusters/my-aks-cluster || echo "Import failed, continuing"
fi

echo "Import process completed"