# Private DB subnet A 
resource "aws_subnet" "private_db_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "192.168.11.0/24"
  map_public_ip_on_launch = false
  availability_zone = local.az_a

  tags = merge(
    var.shared_tags,
    {
      id          = "${local.prj_initials}-network"
      Name        = "${local.prj_initials}-private-subnet-db-a"
    }
  )
}

# Private DB subnet B
resource "aws_subnet" "private_db_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "192.168.12.0/24"
  map_public_ip_on_launch = false
  availability_zone = local.az_b

  tags = merge(
    var.shared_tags,
    {
      id          = "${local.prj_initials}-network"
      Name        = "${local.prj_initials}-private-subnet-db-b"
    }
  )
}

# RDS Security Group 
resource "aws_security_group" "rds_sg" {
  name   = "${local.prj_initials}-rds-sg"
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.shared_tags,
    {
      id          = "${local.prj_initials}-network"
      Name        = "${local.prj_initials}-rds-sg"
    }
  )
}

# Required so Aurora accepts PostgreSQL connections from the Lambda
resource "aws_security_group_rule" "rds_from_lambda" {
  type                     = "ingress"
  description              = "Lambda to Aurora PostgreSQL"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.lambda_sg.id
}

# RDS DB Subnet Group (REQUIRED for RDS)
resource "aws_db_subnet_group" "this" {
  name       = "${local.prj_initials}-db-subnet-group"
  subnet_ids = [aws_subnet.private_db_a.id, aws_subnet.private_db_b.id]

  tags = merge(
    var.shared_tags,
    {
      id          = "${local.prj_initials}-network"
      Name        = "${local.prj_initials}-db-subnet-group"
    }
  )
}