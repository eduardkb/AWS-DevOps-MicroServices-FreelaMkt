locals {
  prj_initials_lambda = lower("${var.project_initials}-${var.project_code}")
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_migration" {
  name               = "${local.prj_initials_lambda}-lambda-migration-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials_lambda}-security"
      Name = "${local.prj_initials_lambda}-lambda-migration-role"
    }
  )
}

# Managed policy: lets Lambda create ENIs inside the VPC (required for VPC Lambda)
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_migration.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Inline policy: read the DB secret and decrypt with KMS
data "aws_iam_policy_document" "lambda_migration_inline" {
  statement {
    sid    = "ReadDBSecret"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [aws_secretsmanager_secret.db_secret.arn]
  }

  statement {
    sid    = "DecryptWithCMK"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.rds_key.arn] 
  }
}

resource "aws_iam_role_policy" "lambda_migration_inline" {
  name   = "${local.prj_initials_lambda}-lambda-migration-policy"
  role   = aws_iam_role.lambda_migration.id
  policy = data.aws_iam_policy_document.lambda_migration_inline.json
}