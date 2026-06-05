# Interface endpoint: Secrets Manager
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

# Interface endpoint: KMS
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


# Interface Endpoint - Security group
resource "aws_security_group" "interf_endpoint_sg" {
  name   = "${local.prj_initials}-interfendpoint-sg"
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-network"
      Name = "${local.prj_initials}-interfendpoint-sg"
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