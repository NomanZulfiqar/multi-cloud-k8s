resource "aws_db_subnet_group" "postgres" {
  name       = "postgres-subnet-group"
  subnet_ids = module.vpc.public_subnets  # Using public subnets for learning purposes

  depends_on = [module.vpc]

  lifecycle {
    ignore_changes = [subnet_ids]
    prevent_destroy = true
  }
  
  tags = {
    Name = "postgres-subnet-group"
  }
}

resource "aws_security_group" "postgres" {
  name        = "postgres-sg"
  description = "Allow PostgreSQL inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "PostgreSQL from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "postgres-sg"
  }
}

resource "aws_db_instance" "postgres" {
  identifier           = "eks-postgres"
  allocated_storage    = 20            # Free tier minimum
  storage_type         = "gp2"         # General Purpose SSD
  engine               = "postgres"
  engine_version       = "13"
  instance_class       = "db.t3.micro" # Free tier eligible
  db_name              = "app_database"
  username             = "app_user"
  password             = "app_password"  # Use AWS Secrets Manager in production
  parameter_group_name = "default.postgres13"
  skip_final_snapshot  = true
  publicly_accessible  = false
  db_subnet_group_name = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]
  apply_immediately    = true

  depends_on = [aws_db_subnet_group.postgres, module.vpc]

  lifecycle {
    ignore_changes = [
      password,
      engine_version,
      allocated_storage,
      instance_class,
      parameter_group_name
    ]
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

# Output the RDS endpoint for application configuration
output "rds_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_username" {
  description = "The master username for the RDS instance"
  value       = aws_db_instance.postgres.username
}

output "rds_database" {
  description = "The database name"
  value       = aws_db_instance.postgres.db_name
}