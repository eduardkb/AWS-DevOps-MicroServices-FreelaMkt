# Private subnet A for Lambda functions (no internet access)
resource "aws_subnet" "private_lambda_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "192.168.21.0/24"
  map_public_ip_on_launch = false
  availability_zone       = local.az_a

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-network"
      Name = "${local.prj_initials}-private-subnet-lambda-a"
    }
  )
}

# Migration Lambda - Security group
resource "aws_security_group" "lambda_sg" {
  name   = "${local.prj_initials}-lambda-sg"
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.shared_tags,
    {
      id          = "${local.prj_initials}-network"
      Name        = "${local.prj_initials}-lambda-sg"
    }
  )
}

# Required so the Lambda can connect to Aurora PostgreSQL
resource "aws_security_group_rule" "lambda_to_rds" {
  type                     = "egress"
  description              = "Lambda to Aurora PostgreSQL"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.lambda_sg.id
  source_security_group_id = aws_security_group.rds_sg.id
}