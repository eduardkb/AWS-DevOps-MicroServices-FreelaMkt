variable "project_initials" {
  description = "Initials for this project"
  type        = string
  default     = "FreelaMkt"
}

variable "location" {
  description = "Region for resources"
  type        = string
  default     = "us-east-1"
}

variable "shared_tags" {
  description = "Shared tags for all resources"
  type = map(string)
  default = {
    "owner" = "Eduard K. Buhali",
    "reason" = "Study - Full AWS Microservices Project"
  }
}

variable "db_username" {
  description = "Default username for PostgreSQL database"
  type        = string
  default     = "pgmaster"
}