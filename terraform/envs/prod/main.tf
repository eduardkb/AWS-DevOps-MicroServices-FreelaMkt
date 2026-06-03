module "global" {
  source = "../../global"
}

module "management" {
  source = "../../modules/management"

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

module "network" {
  source = "../../modules/network" 

  project_initials = module.global.project_initials
  project_code     = module.global.project_code
  shared_tags      = module.global.shared_tags
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
  postgre_secret = module.security.postgre_secret 
  aws_kms_cmk_arn = module.security.aws_kms_cmk_arn

  depends_on = [module.security]
}

module "backend" {
  source = "../../modules/backend"

  project_initials = module.global.project_initials
  project_code     = module.global.project_code
  shared_tags      = module.global.shared_tags

  # from network module
  lambda_subnet_a_id         = module.network.lambda_subnet_a_id
  lambda_subnet_b_id         = module.network.lambda_subnet_b_id
  lambda_security_group_id = module.network.lambda_security_group_id

  # from security module
  lambda_role_arn = module.security.lambda_migration_role_arn
  db_secret_arn   = module.security.db_secret_arn

  # from database module
  aurora_endpoint = module.database.aurora_endpoint
  aurora_port     = module.database.aurora_port
  aurora_name     = module.database.aurora_name

  depends_on = [module.database, module.security, module.network]
}