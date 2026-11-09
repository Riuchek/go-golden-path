output "github_actions_variables" {
  description = "Copy into GitHub Actions variables. None of these are secrets."
  value = {
    AWS_REGION          = var.region
    AWS_DEPLOY_ROLE_ARN = aws_iam_role.github_deployer.arn
    TF_STATE_BUCKET     = module.state_bucket.bucket
    ECR_REPOSITORY      = module.ecr.repository_name
  }
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}
