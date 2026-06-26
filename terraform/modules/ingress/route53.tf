# ---------------------------------------------------------------------------
# Existing Route53 Data source
# ---------------------------------------------------------------------------

data "aws_route53_zone" "this" {
  name         = var.application_dns_zone
  private_zone = false 
}

# ---------------------------------------------------------------------------
# Local values
# ---------------------------------------------------------------------------

locals {
  # Full DNS name for the record.  
  fqdn = var.application_dns_prefix == "" ? var.application_dns_zone : "${var.application_dns_prefix}.${var.application_dns_zone}"
}

# ---------------------------------------------------------------------------
# Route53 records
# ---------------------------------------------------------------------------

# A record (IPv4) – alias to CloudFront
# CloudFront's hosted_zone_id is always Z2FDTNDATAQYW2 (AWS-managed constant),
# but referencing the data source attribute is the canonical Terraform practice.
resource "aws_route53_record" "cloudfront_ipv4" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = local.fqdn
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.main_cf.domain_name
    zone_id                = aws_cloudfront_distribution.main_cf.hosted_zone_id
    evaluate_target_health = false # CloudFront does not support health-check evaluation
  }
}

# AAAA record (IPv6) – required when CloudFront IPv6 is enabled on the distribution
resource "aws_route53_record" "cloudfront_ipv6" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = local.fqdn
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.main_cf.domain_name
    zone_id                = aws_cloudfront_distribution.main_cf.hosted_zone_id
    evaluate_target_health = false
  }
}