# Interface endpoint: Secrets Manager
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.us-east-1.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_lambda_a.id, aws_subnet.private_lambda_b.id]
  security_group_ids  = [aws_security_group.lambda_sg.id]
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
  subnet_ids          = [aws_subnet.private_lambda_a.id, aws_subnet.private_lambda_b.id]
  security_group_ids  = [aws_security_group.lambda_sg.id]
  private_dns_enabled = true

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-network"
      Name = "${local.prj_initials}-vpce-kms"
    }
  )
}