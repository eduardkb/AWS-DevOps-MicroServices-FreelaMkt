resource "random_string" "rand_suffix" {
  length  = 3
  upper   = false
  lower   = true
  numeric = false
  special = false
}