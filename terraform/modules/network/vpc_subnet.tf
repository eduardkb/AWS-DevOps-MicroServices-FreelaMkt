# Fetch available AZs from the current region automatically
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  prj_initials = lower("${var.project_initials}-${var.project_code}")
  az_a         = data.aws_availability_zones.available.names[0]
  az_b         = data.aws_availability_zones.available.names[1]
}

# VPC
resource "aws_vpc" "this" {
  cidr_block = "192.168.0.0/16"

  tags = merge(
    var.shared_tags,
    {
      id          = "${local.prj_initials}-network"
      Name        = "${local.prj_initials}-vpc"
    }
  )
}
