locals {
  prj_initials_lmb = lower("${var.project_initials}-${var.project_code}")
}

data "archive_file" "migration_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../../../db_schema"   # relative to envs/prod/
  output_path = "${path.module}/migration_lambda.zip"
}

resource "aws_lambda_function" "db_migration" {
  function_name    = "${local.prj_initials_lmb}-db-migration"
  filename         = data.archive_file.migration_zip.output_path
  source_code_hash = data.archive_file.migration_zip.output_base64sha256
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  timeout          = 120
  memory_size      = 256
  role             = var.lambda_role_arn

  vpc_config {
    subnet_ids         = [var.lambda_subnet_a_id, var.lambda_subnet_b_id]
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      DB_SECRET_ARN = var.db_secret_arn
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