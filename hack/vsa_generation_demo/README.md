# VSA Generation Demo

This directory contains a complete demonstration of VSA (Verified Source Attestation) generation using the Conforma Knative Service.

## Purpose

Unlike the main `hack/demo.sh` which demonstrates VSA validation with existing signed images, this demo shows the **complete VSA generation workflow** by:

1. Building a fresh container image
2. Signing it with demo keys
3. Creating a snapshot that triggers VSA generation
4. Monitoring the complete VSA creation and upload process

## Files

- **`demo-vsa-generation.sh`** - Main demo script
- **`vsa-demo-resources.yaml`** - Kubernetes resources for VSA generation demo
- **`test-app/`** - Simple test application for building demo images
  - `Dockerfile` - Container definition
  - `README.md` - Application documentation

## Usage

### Easy Demo Runner (Recommended)

```bash
# Use the demo runner for easy mode selection
./hack/vsa_generation_demo/run-demo.sh <mode>

# Available modes:
./hack/vsa_generation_demo/run-demo.sh localhost   # Default - shows expected failures
./hack/vsa_generation_demo/run-demo.sh cluster     # In-cluster registry - shows success
./hack/vsa_generation_demo/run-demo.sh public      # Public image - shows VSA reuse
```

### Manual Mode Selection

```bash
# Default Mode - localhost registry (shows expected failures)
./hack/vsa_generation_demo/demo-vsa-generation.sh

# In-Cluster Registry Mode - accessible from TaskRuns (shows success)
USE_CLUSTER_REGISTRY=true ./hack/vsa_generation_demo/demo-vsa-generation.sh

# Public Image Mode - uses pre-signed image (shows VSA reuse)
USE_PUBLIC_IMAGE=true ./hack/vsa_generation_demo/demo-vsa-generation.sh
```

**Modes Explained:**
- **Localhost Mode**: Uses localhost registry, shows expected policy failures, demonstrates VSA generation despite failures
- **Cluster Mode**: Uses in-cluster registry accessible from TaskRuns, shows successful policy validation and VSA generation
- **Public Image Mode**: Uses accessible pre-signed image, shows successful policy validation and VSA reuse

### 🧹 **Automatic Cleanup**

The demo now includes **automatic cleanup** that runs:
- ✅ **On successful completion** - Cleans up all demo resources
- ✅ **On interruption** (Ctrl+C) - Graceful cleanup before exit
- ✅ **On script failure** - Ensures no resources are left behind

Resources automatically cleaned up:
- Demo snapshots and secrets
- Generated signing keys (`vsa-demo-keys.*`)
- Docker registry and images
- Temporary files (`/tmp/vsa-demo-snapshot.yaml`)
- Old TaskRuns (older than 1 hour)

### 🛠️ **Manual Cleanup**

If needed, you can also run manual cleanup:

```bash
# Manual cleanup for troubleshooting
./hack/vsa_generation_demo/cleanup.sh
```

## What This Demo Shows

1. **🏗️ Image Building**: Creates a fresh container image
2. **✍️ Image Signing**: Signs the image with Cosign
3. **🔧 Resource Setup**: Configures ReleasePlan, RPA, and policies
4. **🚀 VSA Generation**: Triggers actual VSA creation (not just validation)
5. **📊 Monitoring**: Watches the complete workflow execution

## Prerequisites

- Docker or Podman for building images
- `cosign` for image signing
- `tkn` CLI for TaskRun monitoring
- Kind cluster with Conforma service deployed

## Key Differences from Main Demo

| Aspect | Main Demo (`hack/demo.sh`) | VSA Generation Demo |
|--------|---------------------------|-------------------|
| **Purpose** | Validation of existing VSAs | Generation of new VSAs |
| **Images** | Pre-signed production images | Freshly built demo images |
| **Result** | "SKIPPED" (intelligent optimization) | "SUCCESS" (actual generation) |
| **Keys** | Uses existing signatures | Generates and uses demo keys |
| **Workflow** | Shows validation efficiency | Shows complete generation |

## Expected Output

The demo should show:
- ✅ Successful image building and signing
- ✅ VSA generation TaskRun execution
- ⚠️ **Expected**: Image accessibility failures (localhost registry not accessible from cluster)
- ⚠️ **Expected**: Policy validation violations
- ✅ **Important**: VSA still generated and uploaded to Rekor successfully
- ✅ Complete workflow timing metrics

### 📋 **Understanding the "Errors"**

The demo intentionally uses a localhost registry (`localhost:5001`) which creates **expected failures**:

1. **Image Accessibility Error**: ✅ **Expected**
   ```
   ✕ [Violation] builtin.image.accessible
   Reason: Image URL is not accessible: Get "https://localhost:5001/v2/": dial tcp [::1]:5001: connect: connection refused
   ```

2. **TaskRun "Failure"**: ✅ **Expected**
   ```
   Error: success criteria not met
   ```

3. **VSA Generation Success**: ✅ **Key Point**
   ```
   [VSA] Successfully uploaded VSA to Rekor as single in-toto 0.0.2 entry
   ```

**This demonstrates that VSAs are generated even when policy validation fails**, which is the correct behavior for supply chain attestation.

This proves that the Conforma Knative Service can handle **both validation and generation** workflows effectively.

## 🧹 **Cleanup**

```bash
# Clean up all demo resources
./cleanup.sh
```

## 📁 **Generated Files**

The demo creates temporary files in this directory:
- `vsa-demo-keys.key` - Private signing key (automatically cleaned up)
- `vsa-demo-keys.pub` - Public verification key (automatically cleaned up)

These files are automatically removed by the cleanup script and should not be committed to git.
