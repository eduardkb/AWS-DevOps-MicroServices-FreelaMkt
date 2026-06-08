output "ecr_repository_url" {
  value = aws_ecr_repository.webapp.repository_url  
}

output "ecs_cluster_name" {
  description = "ECS Cluster Name"
  value       = aws_ecs_cluster.webapp.name
}

output "ecs_service_name" {
  description = "ECS Service Name"
  value       = aws_ecs_service.webapp.name  
}