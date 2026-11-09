locals {
  tags = merge(var.tags, {
    platform = "golden-path"
    service  = var.name
  })
}

data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.name}"
  retention_in_days = 14
  tags              = local.tags
}

resource "aws_iam_role" "execution" {
  name = "${var.name}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name = "${var.name}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

# The collector, not the app, writes traces and metrics. Keep the app role
# empty until the service needs an AWS API. That is the platform contract.
resource "aws_iam_role_policy" "collector" {
  name = "${var.name}-collector"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "logs:PutLogEvents",
        "logs:CreateLogStream",
        "cloudwatch:PutMetricData",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_security_group" "service" {
  name        = "${var.name}-ecs"
  description = "Ingress for the golden-path service"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_ecs_cluster" "this" {
  name = var.name
  tags = local.tags
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  # Chainguard static has no shell, so there is no container healthCheck here.
  # The collector config is read from OTEL_CONFIG via --config=env:OTEL_CONFIG.
  container_definitions = jsonencode([
    {
      name      = "collector"
      image     = var.collector_image
      essential = true
      command   = ["--config=env:OTEL_CONFIG"]
      environment = [
        { name = "AWS_REGION", value = data.aws_region.current.region },
        { name = "OTEL_CONFIG", value = var.collector_config },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = "collector"
        }
      }
    },
    {
      name      = var.name
      image     = var.image
      essential = true
      dependsOn = [{
        containerName = "collector"
        condition     = "START"
      }]
      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }]
      environment = [
        { name = "PORT", value = tostring(var.container_port) },
        { name = "OTEL_SERVICE_NAME", value = var.name },
        { name = "OTEL_EXPORTER_OTLP_ENDPOINT", value = "http://127.0.0.1:4318" },
        { name = "OTEL_EXPORTER_OTLP_PROTOCOL", value = "http/protobuf" },
        { name = "OTEL_TRACES_EXPORTER", value = "otlp" },
        { name = "OTEL_METRICS_EXPORTER", value = "otlp" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = var.name
        }
      }
    }
  ])

  tags = local.tags
}

resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.service.id]
    assign_public_ip = var.assign_public_ip
  }

  tags = local.tags
}
