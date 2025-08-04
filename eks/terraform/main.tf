terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.67.0"
    }
  }
  
  backend "s3" {
    bucket         = "noman-rocket-zulfiqar-terraform-backend-us-east-1"
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "noman-rocket-zulfiqar-terraform-backend-us-east-1.lock"
    encrypt        = true
  }
}

# Import existing resources
import {
  to = module.eks.aws_cloudwatch_log_group.this[0]
  id = "/aws/eks/my-eks-cluster/cluster"
}

provider "aws" {
  region = "us-east-1"  # Changed to us-east-1 region
  # Trigger pipeline
}



module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.19.0"

  name = "eks-vpc"
  cidr = "10.0.0.0/16"
  
  # Prevent recreation of VPC
  manage_default_vpc = false

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # Enable auto-assign public IP for public subnets
  map_public_ip_on_launch = true
  
  # Using public subnets only to avoid NAT Gateway costs
  enable_nat_gateway = false
  single_nat_gateway = false
  one_nat_gateway_per_az = false

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.31.2"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.32"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets
  
  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true
  
  # CloudWatch logging configuration
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = 7
  
  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    app_nodes = {
      name         = "app-nodes"
      min_size     = 1
      max_size     = 1
      desired_size = 1

      instance_types = ["t3.small"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 20
      ami_type       = "AL2_x86_64"
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

#  Outputs for kubectl configuration
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "region" {
  description = "AWS region"
  value       = "us-east-1"
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "elasticache_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = aws_elasticache_cluster.redis.cache_nodes.0.address
}

output "elasticache_port" {
  description = "ElastiCache Redis port"
  value       = aws_elasticache_cluster.redis.cache_nodes.0.port
}