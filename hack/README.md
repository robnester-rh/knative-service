# Conforma Knative Service - Demo Scripts

This directory contains demonstration scripts and utilities for the Conforma Knative Service.

## Demo Scripts

### 🔍 VSA Validation Demo (`vsa_validation_demo/`)

Demonstrates **intelligent VSA validation** with existing signed images:

```bash
./hack/vsa_validation_demo/demo-vsa-validation.sh
```

**Shows:**
- Smart VSA discovery in Rekor transparency log
- Intelligent optimization (skips when valid VSAs exist)
- Production-ready efficiency and caching
- **Result**: "SKIPPED" (intelligent behavior)

### 🚀 VSA Generation Demo (`vsa_generation_demo/`)

Demonstrates **complete VSA generation** with fresh images:

```bash
./hack/vsa_generation_demo/demo-vsa-generation.sh
```

**Shows:**
- End-to-end image building and signing
- Actual VSA creation and upload to Rekor
- Complete supply chain security workflow
- **Result**: "SUCCESS" (actual generation)

## Utility Scripts

- **`wait-for-resources.sh`** - Generic resource waiting utility
- **`wait-for-ready-pod.sh`** - Pod readiness waiting utility
- **`check-apiserversource.sh`** - ApiServerSource validation
- **`test_ecp_lookup.sh`** - Enterprise Contract Policy testing

## Demo Comparison

| Aspect | VSA Validation Demo | VSA Generation Demo |
|--------|-------------------|-------------------|
| **Purpose** | Show production efficiency | Show complete capability |
| **Images** | Pre-signed production images | Fresh demo images |
| **VSAs** | Uses existing VSAs | Generates new VSAs |
| **Result** | "SKIPPED" (smart optimization) | "SUCCESS" (actual generation) |
| **Use Case** | Production behavior | Development/testing |
| **Duration** | ~30 seconds | ~2-3 minutes |

## Prerequisites

- Kind cluster with Knative installed
- Conforma Knative Service deployed (`make deploy-local`)
- Docker/Podman (for generation demo)
- `cosign` CLI (for generation demo)
- `tkn` CLI (for TaskRun monitoring)

## Running Demos Consecutively

To run multiple demos without conflicts:

```bash
# Option 1: Use the comprehensive demo runner (recommended)
./hack/run-all-demos.sh

# Option 2: Manual consecutive runs with reset between each
./hack/vsa_validation_demo/demo-vsa-validation.sh
./hack/reset-demo-environment.sh
./hack/vsa_generation_demo/run-demo.sh cluster
./hack/reset-demo-environment.sh
./hack/vsa_generation_demo/run-demo.sh public
```

**Important**: Always run `./hack/reset-demo-environment.sh` between demos to avoid resource conflicts.

## Quick Start

1. **Deploy the service:**
   ```bash
   make setup-knative
   make deploy-local
   ```

2. **Run validation demo:**
   ```bash
   ./hack/vsa_validation_demo/demo-vsa-validation.sh
   ```

3. **Run generation demo:**
   ```bash
   ./hack/vsa_generation_demo/demo-vsa-generation.sh
   ```

## 🧹 **Automatic Cleanup**

Both demos now include **automatic cleanup** that ensures no resources are left behind:

- ✅ **On successful completion** - Cleans up all demo resources
- ✅ **On interruption** (Ctrl+C) - Graceful cleanup before exit  
- ✅ **On script failure** - Ensures clean environment

**No manual cleanup required!** Just run the demos and they'll clean up after themselves.

### Manual Cleanup (if needed)

For troubleshooting, manual cleanup scripts are available:

```bash
# Manual cleanup for validation demo
./hack/vsa_validation_demo/cleanup.sh

# Manual cleanup for generation demo  
./hack/vsa_generation_demo/cleanup.sh
```

Both demos prove that the Conforma Knative Service provides **complete VSA lifecycle management** for enterprise supply chain security! 🏆
