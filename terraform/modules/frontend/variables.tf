variable "project_initials" { type = string }
variable "project_code"     { type = string }
variable "shared_tags"      { type = map(string) }

variable "fargate_subnet_a_id" { type = string }
variable "fargate_security_group_id" { type = string }

variable "alb_subnet_a_id" { type = string }
variable "alb_subnet_b_id" { type = string }
variable "alb_security_group_id" { type = string }
variable "vpc_id" { type = string }

variable "cloudfront_secret_header" {
  description = "Secret header value; requests without it are blocked"
  type        = string
  sensitive   = true
}

variable "acm_certificate_arn" {
  description = "Custom certificate ARN"
  type = string
}