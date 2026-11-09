# Security

This repository deploys infrastructure. A few choices are deliberate:

- GitHub Actions authenticates with Workload Identity Federation. There is no JSON key to leak, and the pool only accepts tokens from `Riuchek/go-golden-path` on `refs/heads/main`.
- The Cloud Run service is private unless `public_invoker` is set.
- The app's GKE service account has no project roles, and its pod does not mount a token.
- The collector is the only identity that can write telemetry.
- State buckets block public access and keep object versioning on.
- Deletion protection defaults to on for Cloud Run and the GKE cluster. The example tfvars turn it off for a sandbox. Do not copy that into a project you care about.
- Do not commit `terraform.tfvars` or a bootstrap `terraform.tfstate`.

The reference service has a fault-injection header, `X-Demo-Fault`. It is a demo switch, not an auth bypass, and it should not be copied into a service that takes real payments.
