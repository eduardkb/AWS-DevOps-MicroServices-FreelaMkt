############################
# HTTP API Gateway (v2)
############################

resource "aws_apigatewayv2_api" "http_api" {
  name          = "${local.prj_initials_lmb}-API-Gateway"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE"]
    allow_headers = ["*"]
  }

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials_lmb}-backend"
      Name = "${local.prj_initials_lmb}-API-Gateway"
    }
  )
}

############################
# Lambda Integrations
############################

resource "aws_apigatewayv2_integration" "user" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.users_api.invoke_arn  
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "service" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.services_api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "booking" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.bookings_api.invoke_arn
  payload_format_version = "2.0"
}

############################
# Routes (/api/*)
############################

# USER
resource "aws_apigatewayv2_route" "user_post" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /api/user"
  target    = "integrations/${aws_apigatewayv2_integration.user.id}"
}

resource "aws_apigatewayv2_route" "user_get_me" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /api/user/me"
  target    = "integrations/${aws_apigatewayv2_integration.user.id}"
}

resource "aws_apigatewayv2_route" "user_put_me" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "PUT /api/user/me"
  target    = "integrations/${aws_apigatewayv2_integration.user.id}"
}

# SERVICE
resource "aws_apigatewayv2_route" "service_post" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /api/service"
  target    = "integrations/${aws_apigatewayv2_integration.service.id}"
}

resource "aws_apigatewayv2_route" "service_get_all" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /api/service"
  target    = "integrations/${aws_apigatewayv2_integration.service.id}"
}

resource "aws_apigatewayv2_route" "service_get_by_id" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /api/service/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.service.id}"
}

resource "aws_apigatewayv2_route" "service_put" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "PUT /api/service/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.service.id}"
}

resource "aws_apigatewayv2_route" "service_delete" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "DELETE /api/service/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.service.id}"
}

# BOOKING
resource "aws_apigatewayv2_route" "booking_post" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /api/booking"
  target    = "integrations/${aws_apigatewayv2_integration.booking.id}"
}

resource "aws_apigatewayv2_route" "booking_get" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /api/booking"
  target    = "integrations/${aws_apigatewayv2_integration.booking.id}"
}

resource "aws_apigatewayv2_route" "booking_update_status" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "PUT /api/booking/{id}/status"
  target    = "integrations/${aws_apigatewayv2_integration.booking.id}"
}

############################
# CloudWatch Logs
############################

resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/apigateway/${aws_apigatewayv2_api.http_api.name}"
  retention_in_days = 14
}

############################
# Stage (deploy + throttling + logging)
############################

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      latency        = "$context.responseLatency"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
    })
  }

  default_route_settings {
    throttling_burst_limit = 10
    throttling_rate_limit  = 5
    detailed_metrics_enabled = true
  }
}

############################
# Lambda permissions
############################

resource "aws_lambda_permission" "user_apigw" {
  statement_id  = "AllowAPIGWInvokeUser"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.users_api.function_name  
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "service_apigw" {
  statement_id  = "AllowAPIGWInvokeService"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.services_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "booking_apigw" {
  statement_id  = "AllowAPIGWInvokeBooking"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bookings_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}