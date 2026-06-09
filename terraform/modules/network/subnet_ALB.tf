#################################################
# Public subnet for ALB (with internet access)
#################################################
resource "aws_subnet" "public_alb_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "192.168.41.0/24"
  map_public_ip_on_launch = true
  availability_zone       = local.az_a

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-network"
      Name = "${local.prj_initials}-public-subnet-alb-a"
    }
  )
}

resource "aws_subnet" "public_alb_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "192.168.42.0/24"
  map_public_ip_on_launch = true
  availability_zone       = local.az_b

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-network"
      Name = "${local.prj_initials}-public-subnet-alb-b"
    }
  )
}

#################################################
# Internet Gateway for ALB subnet
#################################################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-network"
      Name = "${local.prj_initials}-igw"
    }
  )
}


#################################################
# Route Table for ALB subnet
#################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-network"
      Name = "${local.prj_initials}-public-rt"
    }
  )
}

# associate the public route table with the ALB subnet
resource "aws_route_table_association" "public_alb_a" {
  subnet_id      = aws_subnet.public_alb_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_alb_b" {
  subnet_id      = aws_subnet.public_alb_b.id
  route_table_id = aws_route_table.public.id
}

#################################################
# Security Group for ALB subnet
#################################################

resource "aws_security_group" "alb" {
  name        = "${local.prj_initials}-alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.this.id

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-network"
      Name = "${local.prj_initials}-alb-sg"
    }
  )
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront" {
  security_group_id = aws_security_group.alb.id

  description    = "HTTP from CloudFront only"
  ip_protocol    = "tcp"
  from_port      = 80
  to_port        = 80
  prefix_list_id = data.aws_ec2_managed_prefix_list.cloudfront.id
}

resource "aws_vpc_security_group_egress_rule" "alb_to_fargate" {
  security_group_id = aws_security_group.alb.id

  description = "To Fargate"
  ip_protocol = "tcp"
  from_port   = 80
  to_port     = 80

  referenced_security_group_id = aws_security_group.fargate_sg.id
}
