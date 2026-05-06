output "project_initials" {
  value = var.project_initials
}

output "project_code" {
  value = substr(md5(timestamp()), 0, 3)
}

output "location" {
  value = var.location
}

output "shared_tags" {
  value = var.shared_tags
}

output "db_username" {
  value = var.db_username
}