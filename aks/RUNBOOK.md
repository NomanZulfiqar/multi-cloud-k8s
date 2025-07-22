# AKS Application Deployment Runbook

This runbook provides step-by-step instructions for deploying a full-fledged application with PostgreSQL database and Redis cache on Azure Kubernetes Service (AKS).

## Prerequisites

- Azure CLI installed and configured with appropriate permissions
- Terraform installed (v1.0.0+)
- kubectl installed
- Helm installed (v3.0.0+)
- PostgreSQL client tools installed (for data migration)

## Step 1: Deploy Azure Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init -upgrade

# Apply Terraform configuration
terraform apply

# When prompted, type "yes" to confirm
```

This will create:
- Resource Group
- Virtual Network with subnet
- AKS cluster
- Azure Database for PostgreSQL
- Azure Cache for Redis

## Step 2: Configure kubectl for AKS

```bash
# Get AKS credentials
az aks get-credentials --resource-group $(terraform output -raw resource_group_name) --name $(terraform output -raw kubernetes_cluster_name)
```

## Step 3: Migrate Data from EKS (Optional)

If you're migrating from EKS, use the provided script to migrate your database:

```bash
# Make the script executable
chmod +x migrate-data.sh

# Run the migration script
./migrate-data.sh
```

Note: Redis cache doesn't need migration as it's just a cache and can be rebuilt.

## Step 4: Update Application Configuration

Update the database and Redis connection details in `helm-charts/application/values.yaml`:

```bash
# Get PostgreSQL FQDN
POSTGRES_FQDN=$(cd terraform && terraform output -raw postgresql_server_fqdn)

# Get Redis hostname
REDIS_HOST=$(cd terraform && terraform output -raw redis_hostname)

# Update the values.yaml file
sed -i "s|value: \".*:5432\"|value: \"$POSTGRES_FQDN:5432\"|" helm-charts/application/values.yaml
sed -i "s|\${REDIS_ENDPOINT}|$REDIS_HOST|" helm-charts/application/values.yaml
```

## Step 5: Deploy the Application

```bash
# Install the application
helm install sample-app ./helm-charts/application -f helm-charts/application/values.yaml

# Or update an existing installation
helm upgrade sample-app ./helm-charts/application -f helm-charts/application/values.yaml
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

## Database Connection Details

Your application connects to the Azure PostgreSQL database using these environment variables:
- DB_HOST: $(cd terraform && terraform output -raw postgresql_server_fqdn):5432
- DB_PORT: 5432
- DB_NAME: app_database
- DB_USER: app_user
- DB_PASSWORD: app_password (use Azure Key Vault in production)

## Redis Cache Details

Your application connects to the Azure Redis Cache using these environment variables:
- REDIS_HOST: $(cd terraform && terraform output -raw redis_hostname)
- REDIS_PORT: $(cd terraform && terraform output -raw redis_port)

## Cleanup

When you're done with the deployment, you can clean up all resources:

```bash
# Delete the application
helm uninstall sample-app

# Delete Azure resources
cd terraform
terraform destroy

# When prompted, type "yes" to confirm
```

## Troubleshooting

If you encounter any issues during deployment, here are some common problems and their solutions:

### Database Connection Issues

If your application can't connect to the database:

```bash
# Check if the database server is running
az postgres server show --name $(terraform output -raw postgresql_server_name) --resource-group $(terraform output -raw resource_group_name)

# Check if the firewall rules are configured correctly
az postgres server firewall-rule list --server-name $(terraform output -raw postgresql_server_name) --resource-group $(terraform output -raw resource_group_name)
```

### Redis Connection Issues

If your application can't connect to Redis:

```bash
# Check if the Redis cache is running
az redis show --name $(terraform output -raw redis_hostname | cut -d'.' -f1) --resource-group $(terraform output -raw resource_group_name)
```

### Pod Scheduling Issues

If pods are stuck in "Pending" state:

```bash
kubectl describe pod <pod-name>
```

Common issues include:
- Insufficient resources (CPU/memory)
- Node capacity limits
- Taints/tolerations preventing scheduling