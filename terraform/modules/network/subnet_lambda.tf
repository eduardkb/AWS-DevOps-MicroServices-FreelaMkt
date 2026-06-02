# Private subnet A for Lambda functions (no internet access)
resource "aws_subnet" "private_lambda_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "192.168.3.0/24"
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

# Private subnet B for Lambda functions (no internet access)
resource "aws_subnet" "private_lambda_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "192.168.4.0/24"
  map_public_ip_on_launch = false
  availability_zone       = local.az_b

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-network"
      Name = "${local.prj_initials}-private-subnet-lambda-b"
    }
  )
}

# Migration Lambda - Security group
resource "aws_security_group" "lambda_sg" {
  name   = "${local.prj_initials}-lambda-sg"
  vpc_id = aws_vpc.this.id

  # Lambda needs to call Aurora (PostgreSQL) — outbound only
  egress {
    description     = "PostgreSQL to Aurora"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.rds_sg.id]
  }

  # Lambda needs to call AWS service endpoints (Secrets Manager, KMS)
  egress {
    description = "HTTPS to VPC endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block] 
  }

  # TODO: temporary for migration lambda hanging. correção definitiva é fazer um security group só para os endpoints
  ingress {
    description = "HTTPS from self"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    self        = true
  }

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-network"
      Name = "${local.prj_initials}-lambda-sg"
    }
  )
}

# Allow the Lambda SG to reach Aurora — add an ingress rule on the RDS SG
resource "aws_security_group_rule" "rds_from_lambda" {
  type                     = "ingress"
  description              = "Allow Lambda migration function to reach Aurora"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.lambda_sg.id
}