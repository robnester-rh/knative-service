# VSA Validation Demo

This directory contains a demonstration of VSA (Verified Source Attestation) validation using the Conforma Knative Service.

## Purpose

This demo shows the **intelligent VSA validation workflow** by:

1. Using pre-signed production container images
2. Demonstrating smart VSA discovery in Rekor transparency log
3. Showing intelligent optimization (skipping when valid VSAs exist)
4. Validating existing signatures and attestations

## Files

- **`demo-vsa-validation.sh`** - Main validation demo script
- **`validation-demo-resources.yaml`** - Kubernetes resources for validation demo

## Usage

```bash
# Run the VSA validation demo (includes automatic cleanup)
./hack/vsa_validation_demo/demo-vsa-validation.sh
```

### 🧹 **Automatic Cleanup**

The demo now includes **automatic cleanup** that runs:
- ✅ **On successful completion** - Cleans up all demo resources
- ✅ **On interruption** (Ctrl+C) - Graceful cleanup before exit
- ✅ **On script failure** - Ensures no resources are left behind

Resources automatically cleaned up:
- Demo snapshots (`vsa-validation-demo-snapshot`)
- Demo Kubernetes resources (ReleasePlan, RPA, ECP)
- Old TaskRuns (older than 1 hour)

### 🛠️ **Manual Cleanup**

If needed, you can also run manual cleanup:

```bash
# Manual cleanup for troubleshooting
./hack/vsa_validation_demo/cleanup.sh
```

## What This Demo Shows

1. **🔧 Resource Setup**: Configures ReleasePlan, RPA, and policies
2. **📦 Snapshot Processing**: Creates snapshot with pre-signed images
3. **🧠 Smart Discovery**: Finds existing VSAs in Rekor transparency log
4. **⚡ Intelligent Optimization**: Skips validation when valid VSAs exist
5. **📊 Performance**: Shows efficient processing with caching

## Expected Output

The demo should show:
- ✅ Successful resource discovery (ReleasePlan, RPA, ECP)
- ✅ VSA discovery in Rekor transparency log
- ✅ "Valid VSA found, skipping validation" (intelligent optimization)
- ✅ "Result: SKIPPED" (efficient behavior)

## Key Features Demonstrated

- **🧠 Intelligence**: Avoids duplicate work when VSAs already exist
- **⚡ Performance**: Fast processing through smart caching
- **🔍 Discovery**: Finds and validates existing VSAs
- **📊 Optimization**: Shows production-ready efficiency

## Comparison with VSA Generation Demo

| Aspect | VSA Validation Demo | VSA Generation Demo |
|--------|-------------------|-------------------|
| **Purpose** | Validate existing VSAs | Generate new VSAs |
| **Images** | Pre-signed production images | Freshly built demo images |
| **Result** | "SKIPPED" (optimization) | "SUCCESS" (generation) |
| **Focus** | Efficiency and intelligence | Complete workflow |
| **Use Case** | Production optimization | Development and testing |

This demo proves that the Conforma Knative Service is **intelligent and efficient** in production environments where VSAs already exist.
