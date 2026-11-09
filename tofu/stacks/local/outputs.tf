output "vpc_id" {
  value = module.network.vpc_id
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "state_bucket" {
  value = module.state_bucket.bucket
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
