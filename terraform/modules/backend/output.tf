output "migration_function_name" {
  value = aws_lambda_function.db_migration.function_name
}

output "migration_function_arn" {
  value = aws_lambda_function.db_migration.arn
}