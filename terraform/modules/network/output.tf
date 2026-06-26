output "subnet_group_name" {
  value = aws_db_subnet_group.this.name 
}

output "rds_security_group_id" {
  value = aws_security_group.rds_sg.id
}

output "lambda_subnet_a_id" {
  value = aws_subnet.private_lambda_a.id
}

output "lambda_security_group_id" {
  value = aws_security_group.lambda_sg.id
}

output "fargate_subnet_a_id" {
  value = aws_subnet.private_fargate_a.id
}

output "fargate_security_group_id" {
  value = aws_security_group.fargate_sg.id
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
}

output "alb_subnet_a_id" {
  value = aws_subnet.public_alb_a.id
}

output "alb_subnet_b_id" {
  value = aws_subnet.public_alb_b.id
}

output "vpc_id" {
  value = aws_vpc.this.id  
}