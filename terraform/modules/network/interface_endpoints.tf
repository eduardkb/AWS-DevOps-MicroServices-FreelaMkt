#############################################
# Interface endpoint: Secrets Manager
#############################################
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.us-east-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_lambda_a.id]
  security_group_ids  = [aws_security_group.interf_endpoint_sg.id]
  private_dns_enabled = true

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-network"
      Name = "${local.prj_initials}-vpce-secretsmanager"
    }
  )
}

#############################################
# Interface endpoint: KMS
#############################################
resource "aws_vpc_endpoint" "kms" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.us-east-1.kms"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_lambda_a.id]
  security_group_ids  = [aws_security_group.interf_endpoint_sg.id]
  private_dns_enabled = true

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-network"
      Name = "${local.prj_initials}-vpce-kms"
    }
  )
}

#############################################
# Security groups for KMS and Secrets Manager Interface Endpoints
#############################################

resource "aws_security_group" "interf_endpoint_sg" {
  name   = "${local.prj_initials}-interfendpoint-sg"
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-network"
      Name = "${local.prj_initials}-lambda-interface-sg"
    }
  )
}

# Required so the Interface Endpoints accept HTTPS connections from the Lambda
resource "aws_security_group_rule" "endpoint_from_lambda" {
  type                     = "ingress"
  description              = "Lambda to Interface Endpoints"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.interf_endpoint_sg.id
  source_security_group_id = aws_security_group.lambda_sg.id
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_endpoint" {
  security_group_id            = aws_security_group.lambda_sg.id
  description                  = "Lambda to VPC Interface Endpoints (Secrets Manager, KMS)"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.interf_endpoint_sg.id
}

#############################################
# Interface endpoint: ECR API
#############################################
data "aws_region" "current" {}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ecr.api"
  vpc_endpoint_type   = "Interface"

  subnet_ids = [
    aws_subnet.private_fargate_a.id
  ]

  security_group_ids = [
    aws_security_group.vpce_sg.id
  ]

  private_dns_enabled = true
  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-network"
      Name = "${local.prj_initials}-vpce-ecr-api"
    }
  )
}

#############################################
# Interface endpoint: ECR Docker
#############################################
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"

  subnet_ids = [
    aws_subnet.private_fargate_a.id
  ]

  security_group_ids = [
    aws_security_group.vpce_sg.id
  ]

  private_dns_enabled = true
  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-network"
      Name = "${local.prj_initials}-vpce-ecr-dkr"
    }
  )
}

#############################################
# Interface endpoint: Cloudwatch
#############################################
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.logs"
  vpc_endpoint_type   = "Interface"

  subnet_ids = [
    aws_subnet.private_fargate_a.id
  ]

  security_group_ids = [
    aws_security_group.vpce_sg.id
  ]

  private_dns_enabled = true
  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-network"
      Name = "${local.prj_initials}-vpce-logs"
    }
  )
}


#############################################
# Security group for ECR and Cloudwatch Endpoints
#############################################

resource "aws_security_group" "vpce_sg" {
  name   = "${local.prj_initials}-vpce-sg"
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-network"
      Name = "${local.prj_initials}-fargate-interface-sg"
    }
  )

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [
      aws_security_group.fargate_sg.id
    ]
  }
}

#############################################
# Interface endpoint: s3
#############################################
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_fargate.id
  ]
}
