###########################################################
# API Lambda Role
###########################################################

data "aws_iam_policy_document" "lambda_api_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_api" {
  name               = "${local.prj_initials_lambda}-lambda-api-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_api_assume_role.json

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials_lambda}-security"
      Name = "${local.prj_initials_lambda}-lambda-api-role"
    }
  )
}

###########################################################
# VPC Access
###########################################################

resource "aws_iam_role_policy_attachment" "lambda_api_vpc_access" {
  role       = aws_iam_role.lambda_api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

###########################################################
# CloudWatch Logs
###########################################################

resource "aws_iam_role_policy_attachment" "lambda_api_basic_execution" {
  role       = aws_iam_role.lambda_api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

###########################################################
# Secrets Manager + KMS
###########################################################

data "aws_iam_policy_document" "lambda_api_inline" {

  statement {
    sid    = "ReadDBSecret"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      aws_secretsmanager_secret.db_secret.arn
    ]
  }

  statement {
    sid    = "DecryptDBSecret"
    effect = "Allow"

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]

    resources = [
      aws_kms_key.rds_key.arn
    ]
  }
}

resource "aws_iam_role_policy" "lambda_api_inline" {
  name   = "${local.prj_initials_lambda}-lambda-api-policy"
  role   = aws_iam_role.lambda_api.id
  policy = data.aws_iam_policy_document.lambda_api_inline.json
}