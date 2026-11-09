module "network" {
  source = "../../modules/network"
  name   = var.name
}

module "ecr" {
  count  = var.create_registry ? 1 : 0
  source = "../../modules/ecr"
  name   = var.name
}

module "service" {
  source = "../../modules/ecs_service"

  name             = var.name
  image            = var.image
  collector_config = file("${path.module}/../../../otel/collector.aws.yaml")
  vpc_id           = module.network.vpc_id
  subnet_ids       = module.network.public_subnet_ids
  assign_public_ip = true
  desired_count    = var.desired_count
}
