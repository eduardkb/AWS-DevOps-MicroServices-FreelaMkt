output "postgre_secret" {
  value = aws_secretsmanager_secret_version.db_secret_value.secret_string
  sensitive = true
}

output "aws_kms_cmk_arn" {
  value = aws_kms_key.rds_key.arn
}

output "lambda_migration_role_arn" {
  value = aws_iam_role.lambda_migration.arn
}

output "lambda_api_role_arn" {
  value = aws_iam_role.lambda_api.arn
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db_secret.arn
}