# Private subnet A for ECS Fargate (no internet access)
resource "aws_subnet" "private_fargate_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "192.168.31.0/24"
  map_public_ip_on_launch = false
  availability_zone       = local.az_a

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-network"
      Name = "${local.prj_initials}-private-subnet-fargate-a"
    }
  )
}

# Fargate - Security group
resource "aws_security_group" "fargate_sg" {
  name   = "${local.prj_initials}-fargate-sg"
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.shared_tags,
    {
      id          = "${local.prj_initials}-network"
      Name        = "${local.prj_initials}-fargate-sg"
    }
  )
}

resource "aws_vpc_security_group_ingress_rule" "fargate_from_alb" {
  security_group_id = aws_security_group.fargate_sg.id

  description = "From ALB"
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80

  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "fargate_outbound" {
  security_group_id = aws_security_group.fargate_sg.id

  description = "Allow all outbound traffic"
  ip_protocol = "-1"

  cidr_ipv4 = "0.0.0.0/0"
}