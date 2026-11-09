# Bootstrap and deploy

## Zero cloud: compose + Chainguard

```bash
docker compose -f deploy/local/docker-compose.yml up --build
./deploy/local/traffic.sh
```

| Surface | URL |
| :--- | :--- |
| Service | http://localhost:8080 |
| LocalStack | http://localhost:4566 |
| Jaeger | http://localhost:16686 |
| Grafana **Checkout RED** | http://localhost:3000 |
| Prometheus | http://localhost:9090 |

## LocalStack + OpenTofu

With LocalStack healthy:

```bash
make tofu-local
```

That applies `tofu/stacks/local`: VPC, S3 state bucket, ECR repo, ECS cluster
and service. Credentials are the LocalStack stubs (`test` / `test`). State
stays on disk under `tofu/stacks/local/`.

## Real AWS, once

You need an AWS account and credentials that can create IAM, S3, and ECR.

```bash
cp tofu/stacks/bootstrap/terraform.tfvars.example tofu/stacks/bootstrap/terraform.tfvars
# edit state_bucket_name

tofu -chdir=tofu/stacks/bootstrap init
tofu -chdir=tofu/stacks/bootstrap apply
```

Copy `github_actions_variables` into the repository's Actions variables:

| Variable | |
| :--- | :--- |
| `AWS_REGION` | |
| `AWS_DEPLOY_ROLE_ARN` | GitHub OIDC deploy role |
| `TF_STATE_BUCKET` | |
| `ECR_REPOSITORY` | usually `checkout` |

Bootstrap state stays on the machine that applied it. The bucket it creates is
the backend for `tofu/stacks/aws`.

## Deploy from GitHub Actions

Push to `main`, or run **Deploy AWS**. The workflow assumes the OIDC role,
builds the Chainguard-based image, pushes to ECR, and applies
`tofu/stacks/aws`.

To apply by hand after an image exists:

```bash
tofu -chdir=tofu/stacks/aws init \
  -backend-config="bucket=BUCKET" \
  -backend-config="key=stacks/aws/terraform.tfstate" \
  -backend-config="region=us-east-1"

tofu -chdir=tofu/stacks/aws apply \
  -var="image=ACCOUNT.dkr.ecr.us-east-1.amazonaws.com/checkout:tag" \
  -var="create_registry=false"
```

## Destroy

Destroy the aws stack before emptying the state bucket. LocalStack:
`make down` wipes the emulator volume; delete `tofu/stacks/local/*.tfstate*`
if you want a clean apply next time.
