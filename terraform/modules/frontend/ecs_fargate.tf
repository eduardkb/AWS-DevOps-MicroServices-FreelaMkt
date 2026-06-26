locals {
  prj_initials = lower("${var.project_initials}-${var.project_code}")
  app_version  = trimspace(replace(
    file("${path.root}/../../../frontend_webApp/appVersion.env"),
    "APP_VERSION=", ""
  ))
  API_FQDN = var.application_dns_prefix == "" ? "https://${var.application_dns_zone}/api" : "https://${var.application_dns_prefix}.${var.application_dns_zone}/api"
}

data "aws_region" "current" {}

resource "random_id" "secret_key" {
  byte_length = 31   # produces 62 hex characters
}

#################################################
# ECS Cluster
#################################################

resource "aws_ecs_cluster" "webapp" {
  name = "${local.prj_initials}-webapp-cluster"

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-frontend"
      Name = "${local.prj_initials}-webapp-cluster"
    }
  )
}

#################################################
# ECS Task Execution Role
#################################################

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${local.prj_initials}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-frontend"
      Name = "${local.prj_initials}-ecs-task-execution-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

#################################################
# ECS Task Definition
#################################################

resource "aws_ecs_task_definition" "webapp" {
  family                   = "${local.prj_initials}-webapp-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = 256
  memory = 512

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "webapp"
      image     = "${aws_ecr_repository.webapp.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "FLASK_ENV",   value = "production" },
        { name = "SECRET_KEY",  value = random_id.secret_key.hex },
        { name = "API_URL",     value = local.API_FQDN },
        { name = "APP_VERSION", value = local.app_version },
        { name = "COGNITO_CLIENT_ID", value = var.cognito_client_id },
        { name = "COGNITO_DOMAIN", value = var.cognito_domain },
        { name = "COGNITO_REDIRECT_URI", value = var.cognito_redirect_uri },
        { name = "COGNITO_LOGOUT_URI", value = var.cognito_logout_uri }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.webapp.name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-frontend"
      Name = "${local.prj_initials}-webapp-task-definition"
    }
  )
}

#################################################
# CloudWatch Logs
#################################################

resource "aws_cloudwatch_log_group" "webapp" {
  name              = "/ecs/${local.prj_initials}-webapp"
  retention_in_days = 30

  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-frontend"
      Name = "${local.prj_initials}-webapp-logs"
    }
  )
}

#################################################
# ECS Service
#################################################

resource "aws_ecs_service" "webapp" {
  name            = "${local.prj_initials}-webapp-service"
  cluster         = aws_ecs_cluster.webapp.id
  task_definition = aws_ecs_task_definition.webapp.arn

  desired_count = 1
  launch_type   = "FARGATE"

  network_configuration {
    subnets = [ var.fargate_subnet_a_id ]
    security_groups = [ var.fargate_security_group_id ]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.frontend.arn
    container_name = "webapp"
    container_port = 80
  }


  tags = merge(
    var.shared_tags,
    {
      id   = "${local.prj_initials}-frontend"
      Name = "${local.prj_initials}-webapp-service"
    }
  )

  depends_on = [ aws_lb_listener.https ]
}