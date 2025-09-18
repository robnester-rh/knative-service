# Local Development with Kind Clusters

This document explains how to develop and deploy the Conforma Verifier Listener locally using kind clusters with locally built images.

## Overview

The `make deploy-local` target automatically detects your environment and chooses the best deployment strategy:

1. **Kind clusters**: Uses optimized local image building and loading (no registry needed)
2. **Other clusters**: Uses registry-based deployment (requires `KO_DOCKER_REPO` configuration)
3. **Pre-built images**: Alternative approach using `quay.io/conforma/knative-service:latest`

## Prerequisites

- [kind](https://kind.sigs.k8s.io/) installed
- [ko](https://github.com/ko-build/ko) installed
- [kn](https://knative.dev/docs/client/) with quickstart plugin
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed
- Docker daemon running

## Quick Setup

### 1. Setup Knative Cluster

```bash
make setup-knative
```

This creates a kind cluster named "knative" with both Knative Serving and Eventing installed.

### 2. Deploy with Smart Detection

```bash
make deploy-local
```

This will:
- Build the Go application locally using `ko`
- Load the image into the kind cluster
- Deploy all Kubernetes resources
- Wait for pods to be ready
- Display the service URL

**Expected Duration:** ~1-2 minutes

### 3. Deploy with Pre-built Images (Alternative)

If you want to use the pre-built image instead:

```bash
# Modify config/base/knative-service.yaml to use:
# image: quay.io/conforma/knative-service:latest

kustomize build config/dev/ | kubectl apply -f -
```

**Expected Duration:** ~30-60 seconds

## How It Works

### Local Build Process

The `make deploy-local` target contains smart detection logic which:

**For Kind clusters:**
1. **Detects kind**: Checks `kubectl config current-context` for "kind" prefix
2. **Builds locally**: `ko build --local ./cmd/launch-taskrun` (no registry push)
3. **Loads into kind**: `kind load docker-image <image>` makes image available to cluster
4. **Resolves and deploys**: `ko resolve` + `kubectl apply` deploys the manifests

**For other clusters:**
1. **Uses registry**: Builds and pushes to `KO_DOCKER_REPO` registry
2. **Deploys normally**: `ko apply` handles build, push, and deployment
3. **Waits for all components**: Including event sources and triggers

### Configuration Files

- `.ko.yaml` - Ko build configuration
- `Makefile` - Contains smart deployment logic in `deploy-local` target
- `config/base/knative-service.yaml` - Uses `ko://` prefix for local builds

## Troubleshooting

### Image Pull Errors

If you see errors like "Unable to fetch image", it means:
- The image wasn't properly loaded into the kind cluster
- The image name doesn't match what's expected

**Solution**: Use `make deploy-local` which automatically handles image loading for kind clusters.

### Build Failures

If `ko build` fails:
- Ensure Go modules are tidy: `make tidy`
- Check that Docker daemon is running
- Verify ko is properly installed: `ko version`

### Pod Not Ready

If pods don't become ready:
- Check events: `kubectl get events -n default --sort-by='.lastTimestamp'`
- Check pod logs: `kubectl logs -l serving.knative.dev/service=conforma-verifier-listener -n default`
- Verify Knative is installed: `make check-knative`

## Development Workflow

1. **Make code changes** in `cmd/launch-taskrun/`
2. **Redeploy**: `make deploy-local` (automatically optimized for your environment)
3. **Test**: `make test-local`
4. **View logs**: `make logs-local`
5. **Check status**: `make status`

## Available Make Targets

- `make setup-knative` - Create kind cluster with Knative
- `make deploy-local` - Smart deployment (auto-detects kind vs registry-based)
- `make undeploy-local` - Clean up deployment
- `make status` - Show deployment status
- `make logs-local` - View service logs
- `make test-local` - Test with sample snapshot

## Performance Comparison

| Method | Build Time | Deploy Time | Total Time | Use Case |
|--------|------------|-------------|------------|----------|
| Pre-built image | 0s | ~30s | ~30s | Quick testing |
| `make deploy-local` (kind) | ~30s | ~60s | ~90s | Development on kind |
| `make deploy-local` (registry) | ~60s | ~2-5min | ~3-6min | Development on remote clusters |

## Tips

- Use `make deploy-local` for all development (automatically optimized)
- Use pre-built images for quick testing or CI
- The locally built image includes your latest code changes
- Kind cluster persists between sessions unless deleted
- Use `make undeploy-local` to clean up before switching approaches
