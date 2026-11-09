module "state_bucket" {
  source = "../../modules/state_bucket"
  name   = var.state_bucket_name
}

module "ecr" {
  source = "../../modules/ecr"
  name   = "checkout"
}

data "aws_caller_identity" "current" {}

# GitHub Actions → AWS without a long-lived access key.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
}

locals {
  oidc_provider_arn = var.create_github_oidc ? aws_iam_openid_connect_provider.github[0].arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

resource "aws_iam_role" "github_deployer" {
  name = "github-deployer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:ref:refs/heads/main"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github_deployer" {
  name = "github-deployer"
  role = aws_iam_role.github_deployer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:*", "ecs:*", "ec2:*", "elasticloadbalancing:*", "iam:PassRole", "iam:GetRole", "iam:CreateRole", "iam:DeleteRole", "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:TagRole", "logs:*", "xray:*", "cloudwatch:*", "s3:*"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "state_deployer" {
  bucket = module.state_bucket.bucket

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DeployerStateAccess"
      Effect    = "Allow"
      Principal = { AWS = aws_iam_role.github_deployer.arn }
      Action    = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
      Resource = [
        module.state_bucket.arn,
        "${module.state_bucket.arn}/*",
      ]
    }]
  })
}
