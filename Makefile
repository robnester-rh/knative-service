# Variables
KUBECONFIG ?= $(HOME)/.kube/config
NAMESPACE ?= default
KO_DOCKER_REPO ?= ko.local

# Knative versions
KNATIVE_VERSION ?= v1.18.2

# Default target
.PHONY: help
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

.PHONY: setup-knative
setup-knative: ## Install and configure a kind cluster wit knative installed
	@# Nuke the existing cluster if it exists
	kind delete cluster -n knative
	@# Create a new one
	kn quickstart kind

.PHONY: check-knative
check-knative: ## Check if Knative is properly installed
	@echo "Checking Knative installation..."
	@kubectl get crd | grep -E "(serving|eventing)" || (echo "Knative CRDs not found. Run 'make setup-knative' first." && exit 1)
	@echo "Knative is properly installed!"

.PHONY: build
build: ## Build the service using ko
	@echo "Building service with ko..."
	ko build ./cmd/launch-taskrun

.PHONY: build-local
build-local: ## Build the service locally using ko (for testing)
	@echo "Building service locally with ko..."
	ko build --local ./cmd/launch-taskrun

.PHONY: deploy-with-knative-setup
deploy-with-knative-setup: setup-knative deploy-local ## Setup Knative and deploy the service


.PHONY: logs
logs: ## Show logs from the service
	@echo "Showing logs from conforma-knative-service..."
	kubectl logs -n $(NAMESPACE) -l serving.knative.dev/service=conforma-knative-service --tail=100 -f

.PHONY: deploy-local
deploy-local: check-knative ## Deploy the service to local development environment
	@if kubectl config current-context | grep -q "kind"; then \
		echo "🔍 Detected kind cluster, using optimized local deployment..."; \
		echo "🔨 Building image locally with ko..."; \
		IMAGE_NAME=$$(ko build --local ./cmd/launch-taskrun 2>/dev/null | tail -1); \
		echo "Built image: $$IMAGE_NAME"; \
		echo "📦 Loading image into kind cluster..."; \
		CLUSTER_NAME=$$(kubectl config current-context | sed 's/kind-//'); \
		kind load docker-image "$$IMAGE_NAME" --name "$$CLUSTER_NAME"; \
		echo "🚀 Deploying to cluster..."; \
		export KO_DOCKER_REPO=ko.local && kustomize build config/dev/ | KO_DOCKER_REPO=$$KO_DOCKER_REPO ko resolve -f - | kubectl apply -f -; \
		echo "⏳ Waiting for pods to be ready..."; \
		hack/wait-for-ready-pod.sh serving.knative.dev/configuration=conforma-knative-service $(NAMESPACE); \
	else \
		echo "🌐 Using registry-based deployment for non-kind cluster..."; \
		echo "Using KO_DOCKER_REPO: $(KO_DOCKER_REPO)"; \
		kustomize build config/dev/ | KO_DOCKER_REPO=$(KO_DOCKER_REPO) ko apply --bare -f -; \
		echo "⏳ Waiting for pods to be ready..."; \
		hack/wait-for-ready-pod.sh eventing.knative.dev/sourceName=snapshot-events $(NAMESPACE); \
		hack/wait-for-ready-pod.sh serving.knative.dev/configuration=conforma-knative-service $(NAMESPACE); \
	fi
	@echo "✅ Deployment complete!"
	@echo "Service URL:"
	@kubectl get ksvc conforma-knative-service -n $(NAMESPACE) -o jsonpath='{.status.url}' && echo

.PHONY: deploy-staging-local
deploy-staging-local: check-knative ## Deploy locally using infra-deployments staging configuration
	@echo "Deploying conforma-knative-service using infra-deployments staging config..."
	@echo "Using KO_DOCKER_REPO: $(KO_DOCKER_REPO)"
	@echo "Fetching staging configuration from infra-deployments..."
	@trap 'rm -rf /tmp/staging-remote /tmp/staging-kustomization.yaml /tmp/fallback-staging' EXIT; \
	if curl -s https://raw.githubusercontent.com/redhat-appstudio/infra-deployments/main/components/conforma-knative-service/staging/kustomization.yaml > /tmp/staging-kustomization.yaml 2>/dev/null && [ -s /tmp/staging-kustomization.yaml ] && ! grep -q "404" /tmp/staging-kustomization.yaml; then \
		echo "✅ Found infra-deployments staging config"; \
		mkdir -p /tmp/staging-remote; \
		sed 's/namespace: .*/namespace: conforma-local/' /tmp/staging-kustomization.yaml > /tmp/staging-remote/kustomization.yaml; \
		kustomize build /tmp/staging-remote | KO_DOCKER_REPO=$(KO_DOCKER_REPO) ko apply --bare -f -; \
	else \
		echo "⚠️  infra-deployments staging config not yet available, using fallback..."; \
		echo "Creating namespace..."; \
		kubectl create namespace conforma-local --dry-run=client -o yaml | kubectl apply -f -; \
		echo "Deploying with basic configuration..."; \
		mkdir -p /tmp/fallback-staging; \
		cp -r config/base/* /tmp/fallback-staging/; \
		echo "apiVersion: kustomize.config.k8s.io/v1beta1" > /tmp/fallback-staging/kustomization.yaml; \
		echo "kind: Kustomization" >> /tmp/fallback-staging/kustomization.yaml; \
		echo "namespace: conforma-local" >> /tmp/fallback-staging/kustomization.yaml; \
		echo "resources:" >> /tmp/fallback-staging/kustomization.yaml; \
		for file in $$(ls /tmp/fallback-staging/*.yaml | grep -v kustomization); do echo "- $$(basename $$file)" >> /tmp/fallback-staging/kustomization.yaml; done; \
		kustomize build /tmp/fallback-staging | KO_DOCKER_REPO=$(KO_DOCKER_REPO) ko apply --bare -f -; \
	fi
	@echo "Staging-local deployment complete!"
	@echo "Service URL:"
	@kubectl get ksvc conforma-knative-service -n conforma-local -o jsonpath='{.status.url}' && echo

.PHONY: undeploy-local
undeploy-local: ## Remove the local deployment
	@echo "Removing conforma-knative-service..."
	kustomize build config/dev/ | ko delete --ignore-not-found -f -
	@echo "Undeployment complete!"

.PHONY: logs-local
logs-local: ## Show logs from the local service
	@echo "Showing logs from conforma-knative-service..."
	kubectl logs -n $(NAMESPACE) -l serving.knative.dev/service=conforma-knative-service --tail=100 -f

.PHONY: undeploy-staging-local
undeploy-staging-local: ## Remove the staging-local deployment
	@echo "Removing conforma-knative-service from staging-local environment..."
	kubectl delete namespace conforma-local --ignore-not-found
	@echo "Staging-local undeployment complete!"


.PHONY: logs-staging-local
logs-staging-local: ## Show logs from the staging-local service
	@echo "Showing logs from conforma-knative-service in staging-local environment..."
	kubectl logs -n conforma-local -l serving.knative.dev/service=conforma-knative-service --tail=100 -f

.PHONY: test-local
test-local: ## Test local deployment with a sample snapshot
	@echo "Testing local deployment with sample snapshot..."
	kubectl apply -f test-snapshot.yaml -n $(NAMESPACE)
	@echo "Sample snapshot created. Check TaskRuns with:"
	@echo "kubectl get taskruns -n $(NAMESPACE)"

.PHONY: status
status: ## Show deployment status
	@echo "Deployment status:"
	kubectl get all -l app=conforma-knative-service -n $(NAMESPACE)
	@echo ""
	@echo "Knative Service status:"
	kubectl get ksvc conforma-knative-service -n $(NAMESPACE) || echo "Knative Service not found"
	@echo ""
	@echo "Event sources:"
	kubectl get apiserversource -n $(NAMESPACE)
	@echo ""
	@echo "Triggers:"
	kubectl get trigger -n $(NAMESPACE)

.PHONY: test
test: ## Run tests
	@echo "Running tests..."
	cd cmd/launch-taskrun && go test ./... -v

.PHONY: quiet-test
quiet-test: ## Run tests without -v
	@cd cmd/launch-taskrun && go test ./...

.PHONY: test-coverage
test-coverage: ## Run tests with coverage
	@echo "Running tests with coverage..."
	cd cmd/launch-taskrun && go test -v -coverprofile=coverage.out
	go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

.PHONY: lint
lint: ## Run linter
	@echo "Running linter..."
	golangci-lint run ./...

.PHONY: fmt
fmt: ## Format code
	@echo "Formatting code..."
	go fmt ./...

.PHONY: tidy
tidy: ## Tidy go modules
	@echo "Tidying go modules..."
	go mod tidy
