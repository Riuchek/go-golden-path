module "network" {
  source = "../../modules/network"
  name   = var.name
}

module "state_bucket" {
  source        = "../../modules/state_bucket"
  name          = var.state_bucket_name
  force_destroy = true
}

module "ecr" {
  source       = "../../modules/ecr"
  name         = var.name
  force_delete = true
  scan_on_push = false
}

module "service" {
  source = "../../modules/ecs_service"

  name             = var.name
  image            = var.image
  collector_config = file("${path.module}/../../../otel/collector.aws.yaml")
  vpc_id           = module.network.vpc_id
  subnet_ids       = module.network.public_subnet_ids
  assign_public_ip = true
  desired_count    = 1
}
