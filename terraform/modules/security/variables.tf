# Variables from global modules
variable "project_initials" {
  description = "Initials for this project"
  type        = string
}

variable "project_code" {
 description = "Code for this project"
 type        = string  
}

variable "shared_tags" {
  description = "Shared tags for all resources"
  type = map(string)
}

# variable from prod env.
variable "db_username" {
  description = "Database username"
  type = string
}