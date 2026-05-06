# Generate a strong random password
resource "random_password" "postgre_password" {
  length  = 20
  special = true
}

# Create the secret container
resource "aws_secretsmanager_secret" "db_secret" {
  name = "${var.project_initials}-Postgre-credentials"
  region = var.location

    tags = merge(
        var.shared_tags, 
        {
        id          = "${var.project_initials}-Security"
        Name        = "${var.project_initials}-Postgre-credentials"
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