.PHONY: test vet fmt check tf-fmt tf-validate

test:
	cd service && go test ./...

vet:
	cd service && go vet ./...

fmt:
	cd service && gofmt -w .

check: fmt vet test

tf-fmt:
	terraform fmt -recursive terraform

tf-validate:
	terraform fmt -check -recursive terraform
	@for stack in bootstrap cloud-run gke-cluster gke-workload; do \
		echo "==> $$stack"; \
		terraform -chdir=terraform/stacks/$$stack init -backend=false -input=false && \
		terraform -chdir=terraform/stacks/$$stack validate || exit 1; \
	done
