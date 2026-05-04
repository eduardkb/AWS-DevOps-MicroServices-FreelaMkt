resource "aws_rds_cluster" "aurora" {
  cluster_identifier      = "freelamkt-aurora"  # lower("${var.project_initials}aurora")
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned"
  engine_version          = "15.3"
  master_username         = "postgres"
  master_password         = "VeryStrongPassword123!"
  skip_final_snapshot     = true
  
  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 1
  }

  tags = {
    id          = "FreelaMkp-Backend"
    Name        = "freelamkt-aurora"
    Project     = "freelamkt"
  }

}

resource "aws_rds_cluster_instance" "aurora_instance" {
  identifier         = "freelamkt-aurora-instance"  # lower("${var.project_initials}aurora-instance")
  cluster_identifier = aws_rds_cluster.aurora.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.aurora.engine
  tags = {
    id          = "FreelaMkp-Backend"
    Name        = "freelamkt-aurora-instance"
    Project     = "freelamkt"
  }
}