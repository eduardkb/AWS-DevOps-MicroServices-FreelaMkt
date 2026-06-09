locals {
  prj_initials      = lower("${var.project_initials}-${var.project_code}")
  cf_api_origin_id  = "ApiGatewayOrigin"
  cf_alb_origin_id  = "ALBOrigin"
}

resource "aws_cloudfront_distribution" "main_cf" {
  enabled         = true
  is_ipv6_enabled = true
  price_class     = "PriceClass_100"

  # Origin: API Gateway
  origin {
    origin_id   = local.cf_api_origin_id
    domain_name = split("/", replace(var.api_gateway_invoke_url, "https://", ""))[0]

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-CloudFront-Secret"
      value = var.cloudfront_secret_header
    }
  }

  # Origin: ALB
  origin {
    origin_id   = local.cf_alb_origin_id
    domain_name = var.alb_dns_name

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-CloudFront-Secret"
      value = var.cloudfront_secret_header
    }
  }

  # Behaviour: /api/* → API Gateway
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = local.cf_api_origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type"]
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  # Default behaviour: /* → ALB
  default_cache_behavior {
    target_origin_id       = local.cf_alb_origin_id
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      headers      = ["Host"]
      cookies { forward = "all" }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-ingress"
      Name = "${local.prj_initials}-cloudfront"
    }
  )
}