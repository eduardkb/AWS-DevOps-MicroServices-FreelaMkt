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