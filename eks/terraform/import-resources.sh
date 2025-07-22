#!/bin/bash
set -e

# Initialize Terraform
terraform init

# Create a state file backup
if [ -f "terraform.tfstate" ]; then
  cp terraform.tfstate terraform.tfstate.backup
fi

# Modify the existing Terraform files to handle existing resources
echo "Modifying resources to handle existing infrastructure..."

# Add lifecycle blocks to existing resources
sed -i 's/resource "aws_elasticache_subnet_group" "cache_subnet_group" {/resource "aws_elasticache_subnet_group" "cache_subnet_group" {\n  lifecycle {\n    prevent_destroy = true\n    ignore_changes = [subnet_ids]\n  }/' elasticache.tf

sed -i 's/resource "aws_db_subnet_group" "postgres" {/resource "aws_db_subnet_group" "postgres" {\n  lifecycle {\n    prevent_destroy = true\n    ignore_changes = [subnet_ids]\n  }/' rds.tf

# Modify main.tf to disable CloudWatch Log Group creation
sed -i '/subnet_ids = module.vpc.public_subnets/a\n  # Skip creating the CloudWatch Log Group as it already exists\n  create_cloudwatch_log_group = false' main.tf

# Import existing resources
echo "Importing existing resources..."

# Import ElastiCache subnet group
echo "Importing ElastiCache subnet group..."
terraform import aws_elasticache_subnet_group.cache_subnet_group cache-subnet-group || echo "ElastiCache subnet group not found or already imported"

# Import RDS DB subnet group
echo "Importing RDS DB subnet group..."
terraform import aws_db_subnet_group.postgres postgres-subnet-group || echo "RDS DB subnet group not found or already imported"

# Import CloudWatch Logs Log Group
echo "Importing CloudWatch Logs Log Group..."
terraform import module.eks.aws_cloudwatch_log_group.this[0] /aws/eks/my-eks-cluster/cluster || echo "CloudWatch Logs Log Group not found or already imported"

# Run terraform plan to see if our changes fixed the issues
terraform plan -out=tfplan

echo "Import script complete. Resources have been modified to handle existing infrastructure."
echo "You can now run terraform apply to apply the changes."