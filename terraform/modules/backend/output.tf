output "migration_function_name" {
  value = aws_lambda_function.db_migration.function_name
}

output "migration_function_arn" {
  value = aws_lambda_function.db_migration.arn
}

output "api_gateway_invoke_url" {
  description = "API Gateway stage invoke URL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}