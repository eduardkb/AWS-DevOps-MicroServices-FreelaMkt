#################################################
# Application Load Balancer
#################################################

resource "aws_lb" "frontend" {
  name               = "${local.prj_initials}-alb"
  load_balancer_type = "application"
  internal           = false

  security_groups = [var.alb_security_group_id]
  subnets = [ var.alb_subnet_a_id, var.alb_subnet_b_id ]

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-frontend"
      Name = "${local.prj_initials}-alb"
    }
  )
}

#################################################
# Target Group
#################################################

resource "aws_lb_target_group" "frontend" {
  name        = "${local.prj_initials}-alb-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
  }

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-frontend"
      Name = "${local.prj_initials}-alb-tg"
    }
  )
}

#################################################
# HTTPS Listener :443 — primary listener
#################################################

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.frontend.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  # Default action: require the CloudFront secret header
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "allow_cloudfront_https" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 1

  condition {
    http_header {
      http_header_name = "X-CloudFront-Secret"
      values           = [var.cloudfront_secret_header]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}