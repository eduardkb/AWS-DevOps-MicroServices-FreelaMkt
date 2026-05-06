locals {
  postgre_secret = jsondecode(var.postgre_secret)
}

resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = lower("${var.project_initials}-aurora")
  region                  = var.location   
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  # engine_version          = "15.3"
  master_username         = local.postgre_secret["username"]
  master_password         = local.postgre_secret["password"]
  skip_final_snapshot     = true
  db_subnet_group_name   = var.subnet_group_name
  vpc_security_group_ids = [var.rds_security_group_id]

  serverlessv2_scaling_configuration {
    min_capacity = 0
    max_capacity = 1
    seconds_until_auto_pause = 300
  }

  tags = merge(
    var.shared_tags, 
    {
      id          = "${var.project_initials}-Backend"
      Name        = "${var.project_initials}-aurora"
    }
  )
}

resource "aws_rds_cluster_instance" "aurora_instance" {
  identifier         = lower("${var.project_initials}-aurora-instance")
  region             = var.location
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  tags = merge(
    var.shared_tags,
    {
      id          = "${var.project_initials}-Backend"
      Name        = "${var.project_initials}-aurora-instance"
    }
  )
}