variable "project_initials" { type = string }
variable "project_code"     { type = string }
variable "shared_tags"      { type = map(string) }

variable "fargate_subnet_a_id" { type = string }
variable "fargate_security_group_id" { type = string }

variable "alb_subnet_a_id" { type = string }
variable "alb_subnet_b_id" { type = string }
variable "alb_security_group_id" { type = string }
variable "vpc_id" { type = string }