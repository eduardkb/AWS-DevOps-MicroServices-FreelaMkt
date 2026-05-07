output "postgre_secret" {
  value = aws_secretsmanager_secret_version.db_secret_value.secret_string
  sensitive = true
}

output "aws_kms_cmk_arn" {
  value = aws_kms_key.rds_key.arn
}
