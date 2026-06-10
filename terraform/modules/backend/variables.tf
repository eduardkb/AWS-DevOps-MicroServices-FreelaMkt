variable "project_initials" { type = string }
variable "project_code"     { type = string }
variable "shared_tags"      { type = map(string) }
variable "application_dns_prefix" { type = string }
variable "application_dns_zone"   { type = string }

variable "lambda_subnet_a_id"        { type = string }
variable "lambda_security_group_id"  { type = string }
variable "lambda_migration_role_arn"   { type = string }
variable "lambda_api_role_arn"         { type = string }
variable "db_secret_arn"               { type = string }
variable "aurora_endpoint"           { type = string }
variable "aurora_port"               { type = number }
variable "aurora_name"               { type = string }
variable "cloudfront_secret_header"    { type = string }