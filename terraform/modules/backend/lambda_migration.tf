locals {
  prj_initials_lmb = lower("${var.project_initials}-${var.project_code}")
}

# creating a common layer for shared dependencies (psycopg2-binary and boto3) to optimize Lambda package size and deployment time
data "archive_file" "shared_layer_zip" {
  type        = "zip"
  source_dir = "${path.root}/../../../backend_API/shared_layer/python"
  output_path = "${path.module}/shared_layer.zip"
}

resource "aws_lambda_layer_version" "shared" {
  layer_name          = "${local.prj_initials_lmb}-shared"
  filename            = data.archive_file.shared_layer_zip.output_path
  source_code_hash    = data.archive_file.shared_layer_zip.output_base64sha256

  compatible_runtimes = ["python3.12"]
}

# Zipped migration code for Lambda function
data "archive_file" "migration_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../../../backend_API/db_migration_lambda"   # relative to envs/prod/
  output_path = "${path.module}/migration_lambda.zip"
}


# Lambda function for database migration
resource "aws_lambda_function" "db_migration" {
  function_name    = "${local.prj_initials_lmb}-db-migration"
  filename         = data.archive_file.migration_zip.output_path
  source_code_hash = data.archive_file.migration_zip.output_base64sha256
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  timeout          = 120
  memory_size      = 256
  layers           = [aws_lambda_layer_version.shared.arn]
  role             = var.lambda_migration_role_arn

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
      Name = "${local.prj_initials_lmb}-db-migration"
    }
  )
}