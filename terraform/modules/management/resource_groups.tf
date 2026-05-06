resource "aws_resourcegroups_group" "network_group" {
  name        = lower("${var.project_initials}-network-group")
  description = "All network resources tagged with FreelaMkp-Network"
  region      = var.location
  resource_query {
    type = "TAG_FILTERS_1_0"
    
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "id"
          Values = ["${var.project_initials}-Network"]
        }
      ]
    })
  }

  tags = var.shared_tags
}

resource "aws_resourcegroups_group" "backend_group" {
  name        = lower("${var.project_initials}-backend-group")
  description = "All backend resources tagged with FreelaMkp-Backend"
  region      = var.location
  resource_query {
    type = "TAG_FILTERS_1_0"
    
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "id"
          Values = ["${var.project_initials}-Backend"]
        }
      ]
    })
  }

  tags = var.shared_tags
}

resource "aws_resourcegroups_group" "security_group" {
  name        = lower("${var.project_initials}-security-group")
  description = "All security resources tagged with FreelaMkp-Security"
  region      = var.location
  resource_query {
    type = "TAG_FILTERS_1_0"
    
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "id"
          Values = ["${var.project_initials}-Security"]
        }
      ]
    })
  }

  tags = var.shared_tags
}