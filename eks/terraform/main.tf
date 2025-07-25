terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

provider "aws" {
  region = "us-east-1"  # Changed to us-east-1 region
}



module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "eks-vpc"
  cidr = "10.0.0.0/16"
  
  # Prevent recreation of VPC
  manage_default_vpc = false

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

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
  version = "19.21.0"

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.32"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets
  
  # Create CloudWatch Log Group to avoid dependency cycle
  create_cloudwatch_log_group = true
  cloudwatch_log_group_retention_in_days = 7
  cloudwatch_log_group_kms_key_id = ""
  cluster_enabled_log_types = ["api", "audit"]
  
  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true
  
  # Prevent changes to existing resources
  cluster_timeouts = {
    create = "30m"
    update = "60m"
    delete = "30m"
  }
  
  # Ignore changes to tags and other attributes
  cluster_tags = {
    Name = "my-eks-cluster"
  }
  
  # Use IAM role settings compatible with this module version
  iam_role_use_name_prefix = false

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
  
  # Enable aws-auth configmap management
  manage_aws_auth_configmap = true
  create_aws_auth_configmap = true
  
  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      username = "root"
      groups   = ["system:masters"]
    }
  ]
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