output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main_cf.domain_name
}

output "cloudfront_url" {
  description = "Full HTTPS CloudFront URL"
  value       = "https://${aws_cloudfront_distribution.main_cf.domain_name}"
}