output "postgre_secret" {
  value = aws_secretsmanager_secret_version.db_secret_value.secret_string
}