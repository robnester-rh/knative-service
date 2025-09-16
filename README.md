# Conforma Verifier Listener

A Kubernetes-native, event-driven service that automatically triggers enterprise contract verification for application snapshots using Tekton bundles.

## Overview

The Conforma Verifier Listener is a CloudEvents-based service that monitors for the creation of Snapshot resources and automatically triggers compliance verification workflows. It implements an event-driven architecture to bridge CloudEvents with Tekton pipelines, using bundle resolution to dynamically fetch verification tasks from container registries.

## Architecture

### Event-Driven Processing
- Listens for CloudEvents of type `dev.knative.apiserver.resource.add`
- Processes Snapshot resources from the `appstudio.redhat.com/v1alpha1` API
- Automatically creates Tekton TaskRuns for compliance verification

### Bundle Resolution
- Uses Tekton's bundle resolver to fetch tasks from `quay.io/conforma/tekton-task:latest`
- Eliminates the need for pre-installed tasks in the cluster
- Enables dynamic task updates without redeploying the service

### Configuration Management
- ConfigMap-based configuration with caching and TTL
- Supports multiple namespaces with isolated configuration
- Configurable parameters for policy verification

## Features

- **Automated Compliance**: Triggers verification workflows without manual intervention
- **Multi-Namespace Support**: Handles snapshots across different namespaces
- **Configurable Policies**: Supports custom policy configurations and public keys
- **Cloud-Native**: Stateless, horizontally scalable, and Kubernetes-native
- **Bundle-Based**: Dynamic task resolution from container registries

## Configuration

The service reads configuration from a ConfigMap named `taskrun-config` in each namespace:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: taskrun-config
  namespace: default
data:
  POLICY_CONFIGURATION: "github.com/enterprise-contract/config//slsa3"
  PUBLIC_KEY: |
    -----BEGIN PUBLIC KEY-----
    MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEZP/0htjhVt2y0ohjgtIIgICOtQtA
    naYJRuLprwIv6FDhZ5yFjYUEtsmoNcW7rx2KM6FOXGsCX3BNc7qhHELT+g==
    -----END PUBLIC KEY-----
  IGNORE_REKOR: "true"
```

## Deployment

### Prerequisites
- Kubernetes cluster with Tekton installed
- Knative Serving (for CloudEvents support)
- Access to the bundle registry (`quay.io/conforma/tekton-task:latest`)
- [ko](https://github.com/ko-build/ko) installed for building and deploying

### Installation

Deploy all components using Kustomize and ko:

```bash
kustomize build config/dev/ | ko apply -f -
```

### Local Development

Deploy to local development environment:

```bash
# Set your container registry
export KO_DOCKER_REPO=your-registry/conforma

# Deploy to local development
make deploy-local

# View logs
make logs-local

# Test functionality
make test-local
```

### Staging-like Testing

Test locally using Red Hat App Studio staging configuration:

```bash
# Deploy using infra-deployments staging config
make deploy-staging-local

# This fetches the actual staging configuration from infra-deployments
# and deploys it locally for realistic testing
```

The service includes:
- **VSA attestation**: Configurable supply chain security support
- **Enterprise features**: Resource management and health monitoring capabilities
- **Cloud-native design**: Stateless, scalable, Kubernetes-native

### Manual Installation

Deploy using Kustomize and ko directly:

```bash
# Development
kustomize build config/dev/ | ko apply -f -
```

## Usage

Once deployed, the service will automatically:

1. **Monitor** for Snapshot resource creation events
2. **Read** configuration from the snapshot's namespace
3. **Create** Tekton TaskRuns with the appropriate parameters
4. **Execute** enterprise contract verification using bundle resolution

### Example Snapshot
```yaml
apiVersion: appstudio.redhat.com/v1alpha1
kind: Snapshot
metadata:
  name: test-snapshot
  namespace: default
spec:
  application: application-sample
  displayName: test-snapshot
  displayDescription: my first snapshot
  components:
    - name: test-component
      containerImage: "quay.io/redhat-user-workloads/rhtap-contract-tenant/golden-container/golden-container@sha256:185f6c39e5544479863024565bb7e63c6f2f0547c3ab4ddf99ac9b5755075cc9"
```

## Make Targets

The project includes comprehensive Make targets for development and deployment:

### Development Targets
- `make build` - Build the service using ko
- `make test` - Run unit tests
- `make test-coverage` - Run tests with coverage report
- `make lint` - Run linter
- `make fmt` - Format code
- `make tidy` - Tidy go modules
- `make status` - Show deployment status

### Deployment Targets
- `make deploy-with-knative-setup` - Setup Knative and deploy the service
- `make logs` - Show logs from the service

### Local Development
- `make deploy-local` - Deploy to local development environment
- `make undeploy-local` - Remove local deployment
- `make logs-local` - View local service logs
- `make test-local` - Test with sample snapshot
- `make deploy-staging-local` - Deploy locally using infra-deployments staging config
- `make undeploy-staging-local` - Remove staging-local deployment
- `make logs-staging-local` - View staging-local service logs

### Cluster Setup
- `make setup-knative` - Install and configure kind cluster with Knative
- `make check-knative` - Verify Knative installation

### Help
- `make help` - Show all available targets with descriptions

## Development

### Quickstart

* Make sure you have recent versions of `kn`, `kn-quickstart`, `ko`, `kind`, and `tkn` installed.
* Run `make setup-knative`
* Do `export KO_DOCKER_REPO=quay.io/yourquayuser`
* Run `make build`
* Go to <https://quay.io/> and configure the `quay.io/yourquayuser/launch-taskrun-*`
  repo that was just created to be public instead of private.
* Run `make deploy-local`
* Run `hack/demo.sh`

### Building
```bash
make build
```

### Testing
```bash
make test
```

### Running Locally
```bash
go run cmd/launch-taskrun/main.go
```

## Architecture Diagram

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Kubernetes    │    │ Conforma         │    │   Tekton        │
│   API Server    │───▶│ Verifier         │───▶│   Pipeline      │
│                 │    │ Listener         │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │ Bundle Registry  │
                       │ (quay.io/...)   │
                       └──────────────────┘
```

## Documentation

### 🎯 Quick References
- **Development**: Use `make help` to see all available commands
- **Local Testing**: Use `make deploy-local` and `make test-local` for development
- **Staging-like Testing**: Use `make deploy-staging-local` for realistic testing with infra-deployments config

## Container Images

The service is designed to be built and deployed using [ko](https://github.com/ko-build/ko), which handles container image building and deployment directly from Go source code.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

### Development Workflow
- Use `make test` to run unit tests
- Use `make lint` and `make fmt` for code quality
- Use `make deploy-local` for local testing
- Use `make deploy-staging-local` for staging-like testing

## License

[Add your license information here]
