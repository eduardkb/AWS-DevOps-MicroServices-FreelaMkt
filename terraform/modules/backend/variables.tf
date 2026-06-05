variable "project_initials" { type = string }
variable "project_code"     { type = string }
variable "shared_tags"      { type = map(string) }

variable "lambda_subnet_a_id"        { type = string }
variable "lambda_security_group_id"  { type = string }
variable "lambda_migration_role_arn"   { type = string }
variable "lambda_api_role_arn"         { type = string }
variable "db_secret_arn"               { type = string }
variable "aurora_endpoint"           { type = string }
variable "aurora_port"               { type = string }
variable "aurora_name"               { type = string }