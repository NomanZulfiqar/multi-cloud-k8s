# Migrating from EKS to AKS

This guide outlines the steps to migrate your application from Amazon EKS to Azure Kubernetes Service (AKS).

## Prerequisites

- Azure CLI installed and configured
- Terraform installed (v1.0.0+)
- kubectl installed
- Helm installed (v3.0.0+)

## Step 1: Create Azure Terraform Configuration

Create a new directory for your Azure Terraform configuration:

```bash
mkdir -p terraform-azure
cd terraform-azure
```

Create the following Terraform files:

### providers.tf
```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}
```

### main.tf
```hcl
resource "azurerm_resource_group" "this" {
  name     = "aks-resource-group"
  location = "East US"
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
  name                = "aks-cluster"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = "aks-cluster"
  kubernetes_version  = "1.26.6"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"  # Similar to t3.small in AWS
    vnet_subnet_id = azurerm_subnet.this.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    load_balancer_sku = "standard"
  }

  tags = {
    Environment = "dev"
  }
}

resource "azurerm_postgresql_server" "this" {
  name                = "aks-postgres"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  sku_name = "B_Gen5_1"  # Basic tier, Gen5, 1 vCore

  storage_mb                   = 5120
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true

  administrator_login          = "app_user"
  administrator_login_password = "app_password"  # Use Azure Key Vault in production
  version                      = "11"
  ssl_enforcement_enabled      = true
}

resource "azurerm_postgresql_database" "this" {
  name                = "app_database"
  resource_group_name = azurerm_resource_group.this.name
  server_name         = azurerm_postgresql_server.this.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

resource "azurerm_postgresql_firewall_rule" "this" {
  name                = "AllowAllAzureIPs"
  resource_group_name = azurerm_resource_group.this.name
  server_name         = azurerm_postgresql_server.this.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "255.255.255.255"
}
```

### outputs.tf
```hcl
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
```

## Step 2: Deploy Azure Infrastructure

```bash
# Initialize Terraform
terraform init

# Apply Terraform configuration
terraform apply

# When prompted, type "yes" to confirm
```

## Step 3: Configure kubectl for AKS

```bash
# Get AKS credentials
az aks get-credentials --resource-group $(terraform output -raw resource_group_name) --name $(terraform output -raw kubernetes_cluster_name)
```

## Step 4: Update Application Configuration

Modify your `helm-charts/application/values.yaml` to use Azure PostgreSQL:

```bash
# Get PostgreSQL FQDN
POSTGRES_FQDN=$(terraform output -raw postgresql_server_fqdn)

# Update the DB_HOST value in values.yaml
sed -i "s|value: \".*:5432\"|value: \"$POSTGRES_FQDN:5432\"|" ../helm-charts/application/values.yaml
```

## Step 5: Deploy the Application

```bash
cd ..  # Return to project root
helm install sample-app ./helm-charts/application -f helm-charts/application/values.yaml
```

## Step 6: Verify Deployment

```bash
# Check if pods are running
kubectl get pods

# Check if service is created with LoadBalancer
kubectl get services

# Wait for the load balancer to be provisioned
kubectl get service sample-app -o wide

# Get the load balancer IP
echo "Application URL: http://$(kubectl get service sample-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
```

## Step 7: Access Your Application

Open a web browser and navigate to the URL from Step 6.

## Key Differences Between EKS and AKS

1. **Infrastructure Provider**: 
   - EKS: AWS
   - AKS: Azure

2. **Load Balancer**:
   - EKS: AWS Load Balancer Controller
   - AKS: Azure Load Balancer (built-in)

3. **Database**:
   - EKS: Amazon RDS PostgreSQL
   - AKS: Azure Database for PostgreSQL

4. **Networking**:
   - EKS: VPC, Subnets, Security Groups
   - AKS: Virtual Network, Subnets, Network Security Groups

5. **Authentication**:
   - EKS: IAM roles
   - AKS: Azure AD integration

6. **Service Endpoints**:
   - EKS: Load balancer provides DNS hostname
   - AKS: Load balancer provides IP address

## Cleanup

When you're done with the deployment, you can clean up all resources:

```bash
# Delete the application
helm uninstall sample-app

# Delete Azure resources
cd terraform-azure
terraform destroy

# When prompted, type "yes" to confirm
```