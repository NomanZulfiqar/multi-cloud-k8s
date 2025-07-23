resource "aws_elasticache_subnet_group" "cache_subnet_group" {
  name       = "cache-subnet-group"
  subnet_ids = module.vpc.public_subnets
  
  lifecycle {
    prevent_destroy = false
    ignore_changes = [subnet_ids]
  }
}

resource "aws_security_group" "elasticache_sg" {
  name        = "elasticache-security-group"
  description = "Allow Redis traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "elasticache-sg"
  }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "eks-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"  # Cost-optimized instance
  num_cache_nodes      = 1
  parameter_group_name = "default.redis6.x"
  engine_version       = "6.x"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.cache_subnet_group.name
  security_group_ids   = [aws_security_group.elasticache_sg.id]
  
  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      node_type,
      engine_version,
      parameter_group_name
    ]
  }
}