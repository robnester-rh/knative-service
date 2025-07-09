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
kustomize build config/ | ko apply -f -
```

This command will:
1. Build the container image using ko
2. Apply all Kubernetes resources (RBAC, ServiceAccount, Knative Service, etc.)
3. Deploy the service to your cluster

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
      containerImage: "test-image:latest"
```

## Development

### Building
```bash
go build ./cmd/launch-taskrun/
```

### Testing
```bash
go test ./cmd/launch-taskrun/ -v
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

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

[Add your license information here]
