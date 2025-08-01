resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "myapp/db-credentials-v2"
  description             = "Database credentials for the application"
  recovery_window_in_days = 0  # Force immediate deletion
  
  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "app_user",
    password = "app_password"
  })
}

output "secret_arn" {
  description = "The ARN of the secret in AWS Secrets Manager"
  value       = aws_secretsmanager_secret.db_credentials.arn
}