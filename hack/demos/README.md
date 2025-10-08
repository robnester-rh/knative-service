# Conforma VSA Generation Demo

This directory contains a complete demonstration of the Conforma Knative Service's VSA (Verified Source Attestation) generation capabilities.

## Demo Overview

The demo shows end-to-end VSA generation including:
- Building and signing a container image
- Generating SLSA provenance attestations
- Creating and uploading VSAs to Rekor transparency log
- Complete supply chain security workflow

## Quick Start

1. **Deploy the service:**
   ```bash
   make setup-knative
   make deploy-local
   ```

2. **Run the demo:**
   ```bash
   ./hack/demos/demo-vsa-generation.sh
   ```

## What the Demo Does

1. **🔧 Sets up in-cluster registry** - For accessible image storage
2. **🏗️ Builds test application** - Creates a demo container image
3. **🔑 Generates signing keys** - Creates Cosign keys for signing
4. **📝 Configures resources** - Sets up ReleasePlan, RPA, and ECP
5. **🚀 Triggers VSA generation** - Creates snapshot to start workflow
6. **✅ Shows success** - Displays TaskRun completion and VSA upload

## Prerequisites

- Kind cluster with Knative installed
- Conforma Knative Service deployed (`make deploy-local`)
- Docker/Podman for building images
- `cosign` CLI for signing operations
- `tkn` CLI for TaskRun monitoring

## Demo Files

- `demo-vsa-generation.sh` - Main demo script
- `vsa-demo-resources.yaml` - Kubernetes resources (RPA, ECP, etc.)
- `in-cluster-registry.yaml` - In-cluster registry deployment
- `test-app/` - Sample application for building and signing

## Automatic Cleanup

The demo includes automatic cleanup that runs on:
- ✅ Successful completion
- ✅ Script interruption (Ctrl+C)
- ✅ Script failure

No manual cleanup required! The demo cleans up after itself.

## Expected Result

The demo should complete with:
```
🎉 VSA Generation Demo completed successfully!
✅ Image built and signed
✅ VSA generated and uploaded to Rekor
✅ Complete supply chain security demonstrated
```

This proves that the Conforma Knative Service provides complete VSA lifecycle management for enterprise supply chain security! 🏆
