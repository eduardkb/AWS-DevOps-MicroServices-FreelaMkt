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
  default     = "www" 
  # if empty uses apex domain 
  # (*.domanin.com certificate does not cover for domain.com address), 
  # otherwise subdomain (e.g. 'app' for app.edukb.site)
}

variable "certificate_arn" {
  description = "ARN of the TLS certificate"
  type        = string
  default     = "arn:aws:acm:us-east-1:217037953500:certificate/b2cea9a5-92e5-4b86-94d0-da234f086d69"
}

variable "cognito_client_id" {
  default = "l92tb04q2e84ga98lfg0kocdt"
}

variable "cognito_domain" { # ATTENTION: NO HTTPS
  default = "us-east-1udshbayhc.auth.us-east-1.amazoncognito.com"
}

variable "cognito_redirect_uri" {
  default = "https://www.edukb.site/auth/callback"
}

variable "cognito_logout_uri" {
  default = "https://www.edukb.site"
}

variable "cognito_user_pool_id" {
  default = "us-east-1_uDShbAYhC"
}