locals {
  prj_initials_sm = lower("${var.project_initials}-${var.project_code}")
}

# Generate a strong random password
resource "random_password" "postgre_password" {
  length  = 20
  special = true
}

# Create the secret container
resource "aws_secretsmanager_secret" "db_secret" {
  name = "${local.prj_initials_sm}-postgre-credentials"
  region = var.location

  tags = merge(
    var.shared_tags, 
    {
      id          = "${local.prj_initials_sm}-security"
      Name        = "${local.prj_initials_sm}-postgre-credentials"
    }
  )
}

# Store the secret value (JSON format recommended by AWS)
resource "aws_secretsmanager_secret_version" "db_secret_value" {
  secret_id = aws_secretsmanager_secret.db_secret.id
  region = var.location
  
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.postgre_password.result
  })
}