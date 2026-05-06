# Variables from global modules
variable "project_initials" {
  description = "Initials for this project"
  type        = string
}

variable "project_code" {
  description = "project code"
  type        = string
}

variable "location" {
  description = "Region for resources"
  type        = string
}

variable "shared_tags" {
  description = "Shared tags for all resources"
  type = map(string)
}

# from network module
variable "subnet_group_name" {
  type = string
}

variable "rds_security_group_id" {
  type = string
}

# from security module
variable "postgre_secret" {
  type = string
}