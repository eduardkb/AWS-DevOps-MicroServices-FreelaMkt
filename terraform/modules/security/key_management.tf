locals {
  prj_initials_kms = lower("${var.project_initials}-${var.project_code}")
}

resource "aws_kms_key" "rds_key" {
  description             = "CMK for Aurora PostgreSQL"
  region                  = var.location
  deletion_window_in_days = 7

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