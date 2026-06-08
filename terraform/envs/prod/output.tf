output "migration_function_name" {
  value = module.backend.migration_function_name
}

output "ecr_repository_url" {
  value = module.frontend.ecr_repository_url
}

output "ecs_cluster_name" {
  value = module.frontend.ecs_cluster_name
}

output "ecs_service_name" {
  value = module.frontend.ecs_service_name
}