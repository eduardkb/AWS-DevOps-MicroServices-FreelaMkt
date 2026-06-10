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


output "application_dns_zone" {
  value = var.application_dns_zone
}

output "application_dns_prefix" {
  value = var.application_dns_prefix
}

output "certificate_arn" {
  value = var.certificate_arn
}