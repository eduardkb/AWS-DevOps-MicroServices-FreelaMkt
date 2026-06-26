locals {
  prj_initials_kms = lower("${var.project_initials}-${var.project_code}")
}
data "aws_caller_identity" "current" {}

resource "aws_kms_key" "rds_key" {
  description             = "CMK for Aurora PostgreSQL"
  deletion_window_in_days = 7
  
  policy  = jsonencode({
  Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowRDSServiceGrant"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant"
        ]
        Resource = "*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
        }
      },
      {
        Sid    = "AllowRDSUsage"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
  

  tags = merge(
    var.shared_tags, 
    {
      id          = "${local.prj_initials_kms}-security"
      Name        = "${local.prj_initials_kms}-rds-cmk"
    }
  )
}

resource "aws_kms_alias" "rds_key_alias" {
  name          = "alias/${local.prj_initials_kms}-rds"
  target_key_id = aws_kms_key.rds_key.key_id
}