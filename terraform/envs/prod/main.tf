module "global" {
  source = "../../global"
  # Optionally override variable defaults:
  # project_initials = "ekb"
}

module "data" {
  source = "../../modules/database"

#   project_initials = module.global.project_initials
#   location         = module.global.location
#   shared_tags      = module.global.shared_tags  
}