output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = aws_ecs_service.this.name
}

output "security_group_id" {
  value = aws_security_group.service.id
}

output "log_group" {
  value = aws_cloudwatch_log_group.this.name
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}
