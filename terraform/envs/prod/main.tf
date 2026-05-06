module "global" {
  source = "../../global"
  # Optionally override variable defaults:
  # project_initials = "ekb"
}

module "management" {
  source = "../../modules/management"

  project_initials = module.global.project_initials
  location         = module.global.location 
  shared_tags      = module.global.shared_tags
}

module "network" {
  source = "../../modules/netwoek"

  project_initials = module.global.project_initials
  location         = module.global.location
  shared_tags      = module.global.shared_tags
}

module "database" {
  source = "../../modules/database"

  project_initials = module.global.project_initials
  location         = module.global.location
  shared_tags      = module.global.shared_tags

  # From network module outputs
  subnet_group_name      = module.network.subnet_group_name
  rds_security_group_id  = module.network.rds_security_group_id
}