output "project_initials" {
  value = var.project_initials
}

output "project_code" {
  value = random_string.rand_suffix.result
}

output "shared_tags" {
  value = var.shared_tags
}

output "db_username" {
  value = var.db_username
}