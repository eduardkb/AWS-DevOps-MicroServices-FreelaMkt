variable "project_initials" { type = string }
variable "project_code"     { type = string }
variable "shared_tags"      { type = map(string) }

variable "api_gateway_invoke_url" {
  description = "Invoke URL of the API Gateway stage"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  type        = string
}

variable "cloudfront_secret_header" {
  description = "Secret value sent as X-CloudFront-Secret header to origins"
  type        = string
  sensitive   = true
}