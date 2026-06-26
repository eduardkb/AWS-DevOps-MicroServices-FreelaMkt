resource "random_password" "cloudfront_secret" {
  length  = 32
  special = false
}

module "global" {
  source = "../../global"
}

module "ingress" {
  source = "../../modules/ingress"

  project_initials        = module.global.project_initials
  project_code            = module.global.project_code
  shared_tags             = module.global.shared_tags
  application_dns_zone    = module.global.application_dns_zone
  application_dns_prefix  = module.global.application_dns_prefix
  acm_certificate_arn     = module.global.certificate_arn

  api_gateway_invoke_url   = module.backend.api_gateway_invoke_url
  alb_dns_name             = module.frontend.alb_dns_name
  cloudfront_secret_header = random_password.cloudfront_secret.result  

  depends_on = [module.frontend, module.backend]
}

module "frontend" {
  source = "../../modules/frontend"
  project_initials            = module.global.project_initials
  project_code                = module.global.project_code
  shared_tags                 = module.global.shared_tags
  acm_certificate_arn         = module.global.certificate_arn
  application_dns_prefix      = module.global.application_dns_prefix
  application_dns_zone        = module.global.application_dns_zone
  cognito_client_id           = module.global.cognito_client_id
  cognito_domain              = module.global.cognito_domain
  cognito_logout_uri          = module.global.cognito_logout_uri
  cognito_redirect_uri        = module.global.cognito_redirect_uri
  
  # from network module
  fargate_subnet_a_id         = module.network.fargate_subnet_a_id 
  fargate_security_group_id   = module.network.fargate_security_group_id
  alb_subnet_a_id             = module.network.alb_subnet_a_id
  alb_subnet_b_id             = module.network.alb_subnet_b_id
  alb_security_group_id       = module.network.alb_security_group_id
  vpc_id                      = module.network.vpc_id
  cloudfront_secret_header    = random_password.cloudfront_secret.result
}

module "backend" {
  source = "../../modules/backend"

  project_initials = module.global.project_initials
  project_code     = module.global.project_code
  shared_tags      = module.global.shared_tags
  application_dns_prefix = module.global.application_dns_prefix
  application_dns_zone   = module.global.application_dns_zone
  cognito_client_id = module.global.cognito_client_id
  cognito_user_pool_id = module.global.cognito_user_pool_id

  # from network module
  lambda_subnet_a_id         = module.network.lambda_subnet_a_id
  lambda_security_group_id = module.network.lambda_security_group_id

  # from security module
  lambda_migration_role_arn   = module.security.lambda_migration_role_arn
  lambda_api_role_arn         = module.security.lambda_api_role_arn
  db_secret_arn               = module.security.db_secret_arn

  # from database module
  aurora_endpoint = module.database.aurora_endpoint
  aurora_port     = module.database.aurora_port
  aurora_name     = module.database.aurora_name

  cloudfront_secret_header    = random_password.cloudfront_secret.result

  depends_on = [module.database, module.security, module.network]
}

module "database" {
  source = "../../modules/database"

  project_initials = module.global.project_initials
  project_code     = module.global.project_code
  shared_tags      = module.global.shared_tags

  # imported from network module
  subnet_group_name      = module.network.subnet_group_name
  rds_security_group_id  = module.network.rds_security_group_id

  # imported from security module
  postgre_secret    = module.security.postgre_secret 
  aws_kms_cmk_arn   = module.security.aws_kms_cmk_arn

  depends_on        = [module.security]
}

module "management" {
  source = "../../modules/management"

  project_initials = module.global.project_initials
  project_code     = module.global.project_code
  shared_tags      = module.global.shared_tags
}

module "network" {
  source = "../../modules/network" 

  project_initials = module.global.project_initials
  project_code     = module.global.project_code
  shared_tags      = module.global.shared_tags
}

module "security" {
  source = "../../modules/security"

  project_initials = module.global.project_initials
  project_code     = module.global.project_code
  shared_tags      = module.global.shared_tags
  db_username      = module.global.db_username
}