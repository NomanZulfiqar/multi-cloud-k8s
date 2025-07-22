#!/bin/bash
set -e

# Initialize Terraform
terraform init

# Import VPC resources if they exist
echo "Checking for existing VPC resources..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=eks-vpc" --query "Vpcs[0].VpcId" --output text 2>/dev/null || echo "")
if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
  echo "Found existing VPC: $VPC_ID"
  terraform import module.vpc.aws_vpc.this[0] $VPC_ID || echo "VPC already imported or not found"
  
  # Import subnets
  echo "Checking for existing subnets..."
  SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[*].SubnetId" --output text)
  for SUBNET_ID in $SUBNET_IDS; do
    SUBNET_NAME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$SUBNET_ID" "Name=key,Values=Name" --query "Tags[0].Value" --output text)
    if [[ $SUBNET_NAME == *"public"* ]]; then
      echo "Importing public subnet: $SUBNET_ID"
      terraform import "module.vpc.aws_subnet.public[0]" $SUBNET_ID || echo "Subnet already imported or not found"
    elif [[ $SUBNET_NAME == *"private"* ]]; then
      echo "Importing private subnet: $SUBNET_ID"
      terraform import "module.vpc.aws_subnet.private[0]" $SUBNET_ID || echo "Subnet already imported or not found"
    fi
  done
fi

# Import EKS cluster if it exists
echo "Checking for existing EKS cluster..."
CLUSTER_EXISTS=$(aws eks describe-cluster --name my-eks-cluster --query "cluster.name" --output text 2>/dev/null || echo "")
if [ "$CLUSTER_EXISTS" != "" ]; then
  echo "Found existing EKS cluster: $CLUSTER_EXISTS"
  terraform import module.eks.aws_eks_cluster.this[0] my-eks-cluster || echo "EKS cluster already imported or not found"
  
  # Import node groups
  echo "Checking for existing node groups..."
  NODE_GROUPS=$(aws eks list-nodegroups --cluster-name my-eks-cluster --query "nodegroups[*]" --output text 2>/dev/null || echo "")
  for NG in $NODE_GROUPS; do
    echo "Importing node group: $NG"
    terraform import "module.eks.aws_eks_node_group.this[\"app_nodes\"]" my-eks-cluster:$NG || echo "Node group already imported or not found"
  done
fi

# Import ElastiCache subnet group
echo "Importing ElastiCache subnet group..."
terraform import aws_elasticache_subnet_group.cache_subnet_group cache-subnet-group || echo "ElastiCache subnet group not found or already imported"

# Import ElastiCache cluster if it exists
echo "Checking for existing ElastiCache clusters..."
REDIS_EXISTS=$(aws elasticache describe-cache-clusters --query "CacheClusters[?CacheClusterId=='redis-cluster'].CacheClusterId" --output text 2>/dev/null || echo "")
if [ -n "$REDIS_EXISTS" ]; then
  echo "Found existing ElastiCache cluster: $REDIS_EXISTS"
  terraform import aws_elasticache_cluster.redis $REDIS_EXISTS || echo "ElastiCache cluster already imported or not found"
fi

# Import RDS DB subnet group
echo "Importing RDS DB subnet group..."
terraform import aws_db_subnet_group.postgres postgres-subnet-group || echo "RDS DB subnet group not found or already imported"

# Import RDS instances if they exist
echo "Checking for existing RDS instances..."
RDS_INSTANCES=$(aws rds describe-db-instances --query "DBInstances[?DBSubnetGroup.DBSubnetGroupName=='postgres-subnet-group'].DBInstanceIdentifier" --output text 2>/dev/null || echo "")
for RDS_INSTANCE in $RDS_INSTANCES; do
  echo "Found existing RDS instance: $RDS_INSTANCE"
  terraform import aws_db_instance.postgres $RDS_INSTANCE || echo "RDS instance already imported or not found"
done

# Import CloudWatch Logs Log Group
echo "Importing CloudWatch Logs Log Group..."
terraform import module.eks.aws_cloudwatch_log_group.this[0] /aws/eks/my-eks-cluster/cluster || echo "CloudWatch Logs Log Group not found or already imported"

# Import IAM roles if they exist
echo "Checking for existing IAM roles..."
EKS_ROLE=$(aws iam list-roles --query "Roles[?RoleName=='eks-cluster-role'].RoleName" --output text 2>/dev/null || echo "")
if [ -n "$EKS_ROLE" ]; then
  echo "Found existing IAM role: $EKS_ROLE"
  terraform import module.eks.aws_iam_role.this[0] $EKS_ROLE || echo "IAM role already imported or not found"
fi

echo "Import complete. Now you can run terraform plan/apply."