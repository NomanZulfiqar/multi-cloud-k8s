# Cost-Effective AKS Migration Environment

This Terraform configuration creates a minimal, cost-effective Azure environment for learning AKS and migrating from EKS.

## Resources Created

- Resource Group
- Virtual Network and Subnet
- AKS Cluster (with minimal node size)
- PostgreSQL Database (Basic tier)
- Redis Cache (Basic tier)

## Deployment Instructions

1. Initialize Terraform:
   ```
   terraform init
   ```

2. Review the plan:
   ```
   terraform plan
   ```

3. Apply the configuration:
   ```
   terraform apply
   ```

4. Get AKS credentials:
   ```
   az aks get-credentials --resource-group $(terraform output -raw resource_group_name) --name $(terraform output -raw kubernetes_cluster_name)
   ```

## Cost Optimization

This configuration uses:
- Standard_B2s VM size for AKS nodes (cost-effective)
- Basic tier for PostgreSQL and Redis
- No auto-scaling to prevent unexpected costs
- No monitoring components to reduce costs

## Cleanup

To avoid ongoing charges, destroy the resources when done:
```
terraform destroy
```