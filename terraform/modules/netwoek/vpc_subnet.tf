locals {
  prj_initials = lower("${var.project_initials}-${var.project_code}")
}

# VPC
resource "aws_vpc" "this" {
  cidr_block = "192.168.0.0/16"
  region     = var.location

  tags = merge(
    var.shared_tags,
    {
      id          = "${local.prj_initials}-network"
      Name        = "${local.prj_initials}-vpc"
    }
  )
}

# Private A subnet (internal only)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.this.id
  region            = var.location
  cidr_block        = "192.168.1.0/24"
  map_public_ip_on_launch = false
  availability_zone = "${var.location}a"

  tags = merge(
    var.shared_tags,
    {
      id          = "${local.prj_initials}-network"
      Name        = "${local.prj_initials}-private-subnet-a"
    }
  )
}

# Private B subnet (internal only)
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.this.id
  region            = var.location
  cidr_block        = "192.168.2.0/24"
  map_public_ip_on_launch = false
  availability_zone = "${var.location}b"

  tags = merge(
    var.shared_tags,
    {
      id          = "${local.prj_initials}-network"
      Name        = "${local.prj_initials}-private-subnet-b"
    }
  )
}

# Security Group 
resource "aws_security_group" "rds_sg" {
  name   = "${local.prj_initials}-rds-sg"
  region = var.location
  vpc_id = aws_vpc.this.id

  # allow PostgreSQL from your IP
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["179.186.231.0/24"]
  }

  # Required: allow outbound (AWS requirement for RDS)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.shared_tags,
    {
      id          = "${local.prj_initials}-network"
      Name        = "${local.prj_initials}-rds-sg"
    }
  )
}

# DB Subnet Group (REQUIRED for RDS)
resource "aws_db_subnet_group" "this" {
  name       = "${local.prj_initials}-db-subnet-group"
  region     = var.location
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = merge(
    var.shared_tags,
    {
      id          = "${local.prj_initials}-network"
      Name        = "${local.prj_initials}-db-subnet-group"
    }
  )
}