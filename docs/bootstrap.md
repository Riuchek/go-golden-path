# Bootstrap and deploy

You need a GCP project with billing, and `gcloud` authenticated as someone who can enable APIs and create service accounts. The project itself is not created here.

## 1. Bootstrap, once, from your machine

```bash
cp terraform/stacks/bootstrap/terraform.tfvars.example terraform/stacks/bootstrap/terraform.tfvars
# edit project_id and state_bucket_name

terraform -chdir=terraform/stacks/bootstrap init
terraform -chdir=terraform/stacks/bootstrap apply
```

The state file for this stack stays local. Do not commit it. The output `github_actions_variables` is the set of GitHub Actions variables to create on the repository. They are not secrets.

| Variable | Where it comes from |
| :--- | :--- |
| `GCP_PROJECT_ID` | your project |
| `GCP_REGION` | the region you applied |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | the pool provider name |
| `GCP_DEPLOYER_SERVICE_ACCOUNT` | `github-deployer@...` |
| `TF_STATE_BUCKET` | the state bucket |
| `GCP_GKE_CLUSTER` | `golden-path`, only needed for the GKE workflow |

Settings → Secrets and variables → Actions → Variables. The deploy workflows refuse to run as anything but `refs/heads/main`.

## 2. Cloud Run

Push to `main`, or run the **Deploy Cloud Run** workflow. It builds `service/`, pushes `REGION-docker.pkg.dev/PROJECT/services/checkout:SHA`, and applies `terraform/stacks/cloud-run`.

To apply it yourself the image has to exist first:

```bash
gcloud auth configure-docker REGION-docker.pkg.dev
docker build -t REGION-docker.pkg.dev/PROJECT/services/checkout:dev service
docker push REGION-docker.pkg.dev/PROJECT/services/checkout:dev

terraform -chdir=terraform/stacks/cloud-run init \
  -backend-config="bucket=BUCKET" \
  -backend-config="prefix=stacks/cloud-run"

terraform -chdir=terraform/stacks/cloud-run apply \
  -var="project_id=PROJECT" \
  -var="region=REGION" \
  -var="image=REGION-docker.pkg.dev/PROJECT/services/checkout:dev" \
  -var="public_invoker=true" \
  -var="deletion_protection=false"
```

`public_invoker` and `deletion_protection=false` are for a sandbox. The module defaults are private and protected.

The service URL is the `uri` output. The dashboard is in Cloud Monitoring under the name `checkout / Cloud Run`, and traces are in Cloud Trace. Generate a failure on purpose:

```bash
curl -s -X POST "$URL/v1/orders" \
  -H 'content-type: application/json' \
  -H 'X-Demo-Fault: payment' \
  -d '{"sku":"widget","qty":1}'
```

## 3. GKE, if you want the second runtime

Autopilot has a cluster fee and charges for the CPU and memory the pods request. Skip this on a project where that would be a surprise.

```bash
terraform -chdir=terraform/stacks/gke-cluster init \
  -backend-config="bucket=BUCKET" \
  -backend-config="prefix=stacks/gke-cluster"
terraform -chdir=terraform/stacks/gke-cluster apply \
  -var="project_id=PROJECT" \
  -var="region=REGION" \
  -var="deletion_protection=false"
```

Then either push to `main` (the **Deploy GKE workload** workflow) or apply `terraform/stacks/gke-workload` with the same image variable. The workload stack expects the cluster to exist already.

```bash
gcloud container clusters get-credentials golden-path --region REGION --project PROJECT
kubectl -n checkout port-forward svc/checkout 8080:80
```

Set `service_type = "LoadBalancer"` only when you want an external address.

## Destroy

Turn deletion protection off in the tfvars, apply, then destroy. Destroy the workload before the cluster. Destroy Cloud Run before you delete the project. The bootstrap bucket will refuse to be destroyed while it still holds state; empty it on purpose, not by flipping `force_destroy` in a shared project.
