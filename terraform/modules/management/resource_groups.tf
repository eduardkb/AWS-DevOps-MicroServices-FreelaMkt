locals {
  prj_initials = lower("${var.project_initials}-${var.project_code}")
}

resource "aws_resourcegroups_group" "network_group" {
  name        = "${local.prj_initials}-network"
  description = "All network resources tagged with FreelaMkp-Network"
  resource_query {
    type = "TAG_FILTERS_1_0"
    
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "id"
          Values = ["${local.prj_initials}-network"]
        }
      ]
    })
  }

  tags = var.shared_tags
}

resource "aws_resourcegroups_group" "backend_group" {
  name        = "${local.prj_initials}-backend"
  description = "All backend resources tagged with FreelaMkp-Backend"
  resource_query {
    type = "TAG_FILTERS_1_0"
    
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "id"
          Values = ["${local.prj_initials}-backend"]
        }
      ]
    })
  }

  tags = var.shared_tags
}

resource "aws_resourcegroups_group" "security_group" {
  name        = "${local.prj_initials}-security"
  description = "All security resources tagged with FreelaMkp-Security"
  resource_query {
    type = "TAG_FILTERS_1_0"
    
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "id"
          Values = ["${local.prj_initials}-security"]
        }
      ]
    })
  }

  tags = var.shared_tags
}

resource "aws_resourcegroups_group" "frontend_group" {
  name        = "${local.prj_initials}-frontend"
  description = "All frontend resources tagged with FreelaMkp-Frontend"
  resource_query {
    type = "TAG_FILTERS_1_0"
    
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "id"
          Values = ["${local.prj_initials}-frontend"]
        }
      ]
    })
  }

  tags = var.shared_tags
}

resource "aws_resourcegroups_group" "ingress_group" {
  name        = "${local.prj_initials}-ingress"
  description = "All ingress resources tagged with FreelaMkp-Ingress"
  resource_query {
    type = "TAG_FILTERS_1_0"
    
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "id"
          Values = ["${local.prj_initials}-ingress"]
        }
      ]
    })
  }

  tags = var.shared_tags
}