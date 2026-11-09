.PHONY: test vet fmt check tofu-fmt tofu-validate tofu-local up down

test:
	cd service && go test ./...

vet:
	cd service && go vet ./...

fmt:
	cd service && gofmt -w .

check: fmt vet test tofu-fmt tofu-validate

tofu-fmt:
	tofu fmt -recursive tofu

tofu-validate:
	tofu fmt -check -recursive tofu
	@for stack in bootstrap local aws; do \
		echo "==> $$stack"; \
		tofu -chdir=tofu/stacks/$$stack init -backend=false -input=false && \
		tofu -chdir=tofu/stacks/$$stack validate || exit 1; \
	done

up:
	docker compose -f deploy/local/docker-compose.yml up --build -d

down:
	docker compose -f deploy/local/docker-compose.yml down -v

tofu-local:
	AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 \
	TF_VAR_localstack_endpoint=http://localhost:4566 \
	TF_VAR_image=checkout:local \
	tofu -chdir=tofu/stacks/local init -input=false
	AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1 \
	TF_VAR_localstack_endpoint=http://localhost:4566 \
	TF_VAR_image=checkout:local \
	tofu -chdir=tofu/stacks/local apply -input=false -auto-approve
