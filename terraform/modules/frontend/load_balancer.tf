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

# TODO: change to HTTPS listener with ACM certificate once we have a domain and cert set up
#################################################
# HTTP Listener (TEST ONLY)
#################################################

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.frontend.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "allow_cloudfront" {
  listener_arn = aws_lb_listener.http.arn
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

resource "aws_lb_listener_rule" "block_direct" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 2

  condition {
    path_pattern { values = ["/*"] }
  }

  action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }
}