locals {
  postgre_secret = jsondecode(var.postgre_secret)
  prj_initials = lower("${var.project_initials}-${var.project_code}")
}

resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = "${local.prj_initials}-aurora"
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  engine_version          = "16.13"
  master_username         = local.postgre_secret["username"]
  master_password         = local.postgre_secret["password"]
  skip_final_snapshot     = true
  db_subnet_group_name   = var.subnet_group_name
  vpc_security_group_ids = [var.rds_security_group_id]

  storage_encrypted = true
  kms_key_id        = var.aws_kms_cmk_arn
  
  serverlessv2_scaling_configuration {
    min_capacity = 0
    max_capacity = 1
    seconds_until_auto_pause = 300
  }

  tags = merge(
    var.shared_tags, 
    {
      id          = "${local.prj_initials}-backend"
      Name        = "${local.prj_initials}-aurora"
    }
  )
}

resource "aws_rds_cluster_instance" "aurora_instance" {
  identifier         = lower("${local.prj_initials}-aurora-instance")
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  tags = merge(
    var.shared_tags,
    {
      id          = "${local.prj_initials}-backend"
      Name        = "${local.prj_initials}-aurora-instance"
    }
  )
}