output "aurora_endpoint" {
  value = aws_rds_cluster.aurora.endpoint
}

output "aurora_port" {
  value = aws_rds_cluster.aurora.port
}

output "aurora_name" {
  value = aws_rds_cluster.aurora.database_name
}