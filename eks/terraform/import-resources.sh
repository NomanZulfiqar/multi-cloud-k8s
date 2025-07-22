#!/bin/bash
set -e

# Initialize Terraform
terraform init

# Create a state file backup
if [ -f "terraform.tfstate" ]; then
  cp terraform.tfstate terraform.tfstate.backup
fi

# Modify the Terraform files to handle existing resources
echo "Modifying resources to handle existing infrastructure..."

# Modify ElastiCache subnet group resource
cat > elasticache_temp.tf << 'EOF'
resource "aws_elasticache_subnet_group" "cache_subnet_group" {
  name       = "cache-subnet-group"
  subnet_ids = module.vpc.public_subnets
  lifecycle {
    prevent_destroy = true
    ignore_changes = [subnet_ids]
  }
}
EOF

# Modify RDS subnet group resource
cat > rds_temp.tf << 'EOF'
resource "aws_db_subnet_group" "postgres" {
  name       = "postgres-subnet-group"
  subnet_ids = module.vpc.public_subnets
  lifecycle {
    prevent_destroy = true
    ignore_changes = [subnet_ids]
  }
  tags = {
    Name = "postgres-subnet-group"
  }
}
EOF

# Modify CloudWatch Log Group in main.tf
TEMP_FILE=$(mktemp)
cat > $TEMP_FILE << 'EOF'
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.31.2"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.32"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  # Skip creating the CloudWatch Log Group as it already exists
  create_cloudwatch_log_group = false

  # EKS Managed Node Group(s) - using t3.micro for lowest cost
  eks_managed_node_groups = {
    app_nodes = {
      name         = "app-nodes"
      min_size     = 1
      max_size     = 1  # Limiting to just 1 node
      desired_size = 1

      instance_types = ["t3.small"]  # Using t3.small which has higher pod capacity
      capacity_type  = "SPOT"  # Using Spot instances for lower cost
      disk_size      = 20
      ami_type       = "AL2_x86_64"  # Explicitly using Amazon Linux 2 AMI
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}
EOF

# Apply the changes to main.tf
SEARCH_PATTERN="module \"eks\" {([^}]*)}"
REPLACEMENT=$(cat $TEMP_FILE)
awk -v replacement="$REPLACEMENT" '{
  if ($0 ~ /module "eks" {/) {
    print replacement;
    found=1;
    while (getline && !($0 ~ /^}/)) {}
  } else {
    print $0;
  }
}' main.tf > main.tf.new
mv main.tf.new main.tf

# Run terraform plan to see if our changes fixed the issues
terraform plan -out=tfplan

echo "Import script complete. Resources have been modified to handle existing infrastructure."
echo "You can now run terraform apply to apply the changes."