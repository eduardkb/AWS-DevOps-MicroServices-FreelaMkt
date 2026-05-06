# Variables from global modules
variable "project_initials" {
  description = "Initials for this project"
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