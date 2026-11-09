# Security

- GitHub Actions authenticates to AWS with OIDC. There is no long-lived access key. The role trusts only `repo:Riuchek/go-golden-path:ref:refs/heads/main`.
- The service image is Chainguard (`go` build, `static` runtime), nonroot, no shell.
- The app task role starts empty of business permissions. The collector policy is the one that can write X-Ray and metrics.
- State buckets block public access and keep versioning on.
- Do not commit `*.tfvars` or `*.tfstate`.
- LocalStack compose uses throwaway `test` credentials on purpose. Never point those at a real account.
- `X-Demo-Fault` is a demo switch for the reference service, not an auth bypass.
