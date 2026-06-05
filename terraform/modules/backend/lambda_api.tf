##########################################
# users_api Lambda function
##########################################

# zip the users API code for Lambda function
data "archive_file" "users_api_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../../../backend_API/users_api_lambda"   # relative to envs/prod/
  output_path = "${path.module}/users_api.zip"
}

resource "aws_lambda_function" "users_api" {
  function_name    = "${local.prj_initials_lmb}-users-api"
  filename         = data.archive_file.users_api_zip.output_path
  source_code_hash = data.archive_file.users_api_zip.output_base64sha256
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  timeout          = 120
  memory_size      = 256
  layers           = [aws_lambda_layer_version.shared.arn]
  role             = var.lambda_api_role_arn

  vpc_config {
    subnet_ids         = [var.lambda_subnet_a_id]
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      DB_SECRET_ARN = var.db_secret_arn
      DB_HOST       = var.aurora_endpoint
      DB_PORT       = var.aurora_port
      DB_NAME       = var.aurora_name
    }
  }

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials_lmb}-backend"
      Name = "${local.prj_initials_lmb}-users-api"
    }
  )
}

##########################################
# services_api Lambda function
##########################################

# zip the services API code for Lambda function
data "archive_file" "services_api_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../../../backend_API/services_api_lambda"   # relative to envs/prod/
  output_path = "${path.module}/services_api.zip"
}

resource "aws_lambda_function" "services_api" {
  function_name    = "${local.prj_initials_lmb}-services-api"
  filename         = data.archive_file.services_api_zip.output_path
  source_code_hash = data.archive_file.services_api_zip.output_base64sha256
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  timeout          = 120
  memory_size      = 256
  layers           = [aws_lambda_layer_version.shared.arn]
  role             = var.lambda_api_role_arn

  vpc_config {
    subnet_ids         = [var.lambda_subnet_a_id]
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      DB_SECRET_ARN = var.db_secret_arn
      DB_HOST       = var.aurora_endpoint
      DB_PORT       = var.aurora_port
      DB_NAME       = var.aurora_name
    }
  }

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials_lmb}-backend"
      Name = "${local.prj_initials_lmb}-services-api"
    }
  )
}

##########################################
# bookings_api Lambda function
##########################################

# zip the bookings API code for Lambda function
data "archive_file" "bookings_api_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../../../backend_API/bookings_api_lambda"   # relative to envs/prod/
  output_path = "${path.module}/bookings_api.zip"
}

resource "aws_lambda_function" "bookings_api" {
  function_name    = "${local.prj_initials_lmb}-bookings-api"
  filename         = data.archive_file.bookings_api_zip.output_path
  source_code_hash = data.archive_file.bookings_api_zip.output_base64sha256
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  timeout          = 120
  memory_size      = 256
  layers           = [aws_lambda_layer_version.shared.arn]
  role             = var.lambda_api_role_arn

  vpc_config {
    subnet_ids         = [var.lambda_subnet_a_id]
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      DB_SECRET_ARN = var.db_secret_arn
      DB_HOST       = var.aurora_endpoint
      DB_PORT       = var.aurora_port
      DB_NAME       = var.aurora_name
    }
  }

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials_lmb}-backend"
      Name = "${local.prj_initials_lmb}-bookings-api"
    }
  )
}