output "vpc_id" {
  value = module.network.vpc_id
}

output "ecr_repository_url" {
  value = try(module.ecr[0].repository_url, null)
}

output "ecs_cluster" {
  value = module.service.cluster_name
}

output "ecs_service" {
  value = module.service.service_name
}

output "log_group" {
  value = module.service.log_group
}
