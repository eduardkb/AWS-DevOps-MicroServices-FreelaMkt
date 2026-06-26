locals { 
  fqdn = var.application_dns_prefix == "" ? var.application_dns_zone : "${var.application_dns_prefix}.${var.application_dns_zone}"
}

############################
# HTTP API Gateway (v2)
############################

resource "aws_apigatewayv2_api" "http_api" {
  name          = "${local.prj_initials_lmb}-API-Gateway"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE"]
    allow_headers = ["Authorization", "Content-Type"]
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
# JWT Authorizer
############################
data "aws_region" "current" {}

resource "aws_apigatewayv2_authorizer" "cognito_authorizer" {
  api_id          = aws_apigatewayv2_api.http_api.id  
  name            = "cognito-jwt"
  authorizer_type = "JWT"

  identity_sources = [
    "$request.header.Authorization"
  ]

  jwt_configuration {
    audience = [
      var.cognito_client_id      
    ]

    issuer = "https://cognito-idp.${data.aws_region.current.region}.amazonaws.com/${var.cognito_user_pool_id}"
  }
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

  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito_authorizer.id
}

resource "aws_apigatewayv2_route" "user_get_me" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /api/user/me"
  target    = "integrations/${aws_apigatewayv2_integration.user.id}"

  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito_authorizer.id
}

resource "aws_apigatewayv2_route" "user_put_me" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "PUT /api/user/me"
  target    = "integrations/${aws_apigatewayv2_integration.user.id}"

  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito_authorizer.id
}

resource "aws_apigatewayv2_route" "user_healthcheck" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /api/user/healthcheck"
  target    = "integrations/${aws_apigatewayv2_integration.user.id}"  
}

resource "aws_apigatewayv2_route" "user_getparam" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /api/user/getparam"
  target    = "integrations/${aws_apigatewayv2_integration.user.id}"

  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito_authorizer.id
}

# SERVICE
resource "aws_apigatewayv2_route" "service_post" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /api/service"
  target    = "integrations/${aws_apigatewayv2_integration.service.id}"

  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito_authorizer.id
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

  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito_authorizer.id
}

resource "aws_apigatewayv2_route" "service_put" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "PUT /api/service/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.service.id}"

  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito_authorizer.id
}

resource "aws_apigatewayv2_route" "service_delete" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "DELETE /api/service/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.service.id}"

  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito_authorizer.id
}

# BOOKING
resource "aws_apigatewayv2_route" "booking_post" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /api/booking"
  target    = "integrations/${aws_apigatewayv2_integration.booking.id}"

  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito_authorizer.id
}

resource "aws_apigatewayv2_route" "booking_get" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "GET /api/booking"
  target    = "integrations/${aws_apigatewayv2_integration.booking.id}"

  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito_authorizer.id
}

resource "aws_apigatewayv2_route" "booking_update_status" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "PUT /api/booking/{id}/status"
  target    = "integrations/${aws_apigatewayv2_integration.booking.id}"

  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito_authorizer.id
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