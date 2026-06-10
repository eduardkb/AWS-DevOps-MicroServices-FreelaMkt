variable "project_initials" {
  description = "Initials for this project"
  type        = string
  default     = "FMkt"
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

variable "application_dns_zone" {
  description = "DNS zone name for the application"
  type        = string
  default     = "edukb.site"
}

variable "application_dns_prefix" {
  description = "DNS prefix for the application"
  type        = string
  default     = "" # if empty uses apex domain, otherwise subdomain (e.g. 'app' for app.edukb.site)
}

variable "certificate_arn" {
  description = "ARN of the TLS certificate"
  type        = string
  default     = "arn:aws:acm:us-east-1:217037953500:certificate/b2cea9a5-92e5-4b86-94d0-da234f086d69"
}