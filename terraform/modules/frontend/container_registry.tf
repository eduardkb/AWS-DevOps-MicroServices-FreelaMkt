#################################################
# ECR Repository
#################################################

resource "aws_ecr_repository" "webapp" {
  name                 = "${local.prj_initials}-webapp"
  image_tag_mutability = "MUTABLE"
  force_delete         = true 
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-frontend"
      Name = "${local.prj_initials}-webapp-ecr"
    }
  )
}

#################################################
# ECR Repository Lifecycle
#################################################

resource "aws_ecr_lifecycle_policy" "webapp" {
  repository = aws_ecr_repository.webapp.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 tagged releases"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "1.", "2."]   # adjust to your version prefix
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      }
    ]
  })
}