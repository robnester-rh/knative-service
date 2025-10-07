#!/usr/bin/env bash
# Copyright 2025 The Conforma Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# Always work from project root for consistent paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

# Automatic cleanup function
cleanup_generation_demo() {
    echo ""
    echo "🧹 Cleaning up VSA generation demo resources..."
    
    # Remove demo snapshots
    kubectl delete snapshot "${SNAPSHOT_NAME:-vsa-demo-snapshot-*}" --ignore-not-found -n "${DEMO_NAMESPACE}" 2>/dev/null || true
    
    # Remove demo secrets (using standard names)
    kubectl delete secret vsa-signing-key --ignore-not-found -n "${DEMO_NAMESPACE}" 2>/dev/null || true
    kubectl delete secret public-key --ignore-not-found -n openshift-pipelines 2>/dev/null || true
    
    # Remove demo resources (but not core service components)
    kubectl delete -f hack/vsa_generation_demo/vsa-demo-resources.yaml --ignore-not-found 2>/dev/null || true
    
    # Note: We don't remove core service components (generate-vsa task, RBAC, etc.)
    # as they're part of the main service deployment and may be used by other workflows
    
    # Clean up generated keys
    DEMO_KEYS_DIR="hack/vsa_generation_demo"
    rm -f "${DEMO_KEYS_DIR}/vsa-demo-keys.key" "${DEMO_KEYS_DIR}/vsa-demo-keys.pub" 2>/dev/null || true
    
    # Clean up temporary files
    rm -f /tmp/vsa-demo-snapshot.yaml 2>/dev/null || true
    rm -f /tmp/slsa-provenance-cluster.json 2>/dev/null || true
    rm -f /tmp/demo-release-plan.yaml 2>/dev/null || true
    
    # Clean up Docker registry and images
    if [ "${USE_CLUSTER_REGISTRY:-false}" = "true" ]; then
        # Clean up port-forward
        if [ -f /tmp/vsa-demo-port-forward.pid ]; then
            PORT_FORWARD_PID=$(cat /tmp/vsa-demo-port-forward.pid)
            kill "$PORT_FORWARD_PID" 2>/dev/null || true
            rm -f /tmp/vsa-demo-port-forward.pid
        fi
        pkill -f "kubectl.*port-forward.*registry.*5001:5000" 2>/dev/null || true
        
        # Clean up in-cluster registry
        kubectl delete -f hack/vsa_generation_demo/in-cluster-registry.yaml --ignore-not-found 2>/dev/null || true
        docker rmi "${EXTERNAL_REGISTRY:-localhost:5001}/${IMAGE_NAME}:${IMAGE_TAG:-latest}" 2>/dev/null || true
    else
        # Clean up localhost registry
        docker stop vsa-demo-registry 2>/dev/null || true
        docker rm vsa-demo-registry 2>/dev/null || true
        docker rmi "${LOCAL_REGISTRY:-localhost:5001}/${IMAGE_NAME}:${IMAGE_TAG:-latest}" 2>/dev/null || true
    fi
    
    # Clean up old TaskRuns created by this demo
    kubectl get taskruns -n default --no-headers -o custom-columns=":metadata.name,:metadata.creationTimestamp" 2>/dev/null | \
        awk '$2 < "'$(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ)'" {print $1}' | \
        grep -E '^verify-enterprise-contract-' | \
        head -5 | \
        xargs -r kubectl delete taskrun -n default 2>/dev/null || true
    
    echo "  Generation demo cleanup completed"
}

# Set up signal handlers for graceful cleanup
trap cleanup_generation_demo EXIT
trap 'echo ""; echo "🛑 Demo interrupted - cleaning up..."; cleanup_generation_demo; exit 1' INT TERM

echo "🚀 VSA Generation Demo - Complete Workflow"
echo "Working from: $(pwd)"
echo "=========================================="
echo ""

# Clean up any conflicting demo resources from previous runs
echo "🔄 Cleaning up any existing demo resources..."
kubectl delete namespace rhtap-releng-tenant openshift-pipelines registry --ignore-not-found 2>/dev/null || true
# Clean up any existing port-forwards
pkill -f "kubectl.*port-forward.*registry" 2>/dev/null || true
sleep 2

# Configuration
USE_CLUSTER_REGISTRY=${USE_CLUSTER_REGISTRY:-false}
USE_PUBLIC_IMAGE=${USE_PUBLIC_IMAGE:-false}

# Use default namespace with standard secret names (no ConfigMap modification needed)
DEMO_NAMESPACE="default"

if [ "$USE_CLUSTER_REGISTRY" = "true" ]; then
    # Use in-cluster registry accessible from TaskRuns
    LOCAL_REGISTRY="registry.registry.svc.cluster.local:5000"
    # Use port-forward for external access (avoids insecure registry issues)
    EXTERNAL_REGISTRY="localhost:5001"
    
    echo "📋 Using in-cluster registry for successful policy validation"
elif [ "$USE_PUBLIC_IMAGE" = "true" ]; then
    # Use public image (no local registry needed)
    LOCAL_REGISTRY="localhost:5001"  # Not used but kept for compatibility
    EXTERNAL_REGISTRY="localhost:5001"
    echo "📋 Using public image for successful policy validation"
else
    # Use localhost registry (shows expected failures)
    LOCAL_REGISTRY="localhost:5001"
    EXTERNAL_REGISTRY="localhost:5001"
fi

IMAGE_NAME="vsa-demo-app"
IMAGE_TAG="demo-$(date +%s)"
FULL_IMAGE_REF="${LOCAL_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
SNAPSHOT_NAME="vsa-demo-snapshot-$(date +%s)"

# Alternative: Use a publicly accessible image for successful policy validation
if [ "$USE_PUBLIC_IMAGE" = "true" ]; then
    FULL_IMAGE_REF="quay.io/redhat-user-workloads/rhtap-contract-tenant/golden-container/golden-container@sha256:185f6c39e5544479863024565bb7e63c6f2f0547c3ab4ddf99ac9b5755075cc9"
    SNAPSHOT_NAME="vsa-demo-public-$(date +%s)"
elif [ "$USE_CLUSTER_REGISTRY" = "true" ]; then
    SNAPSHOT_NAME="vsa-demo-cluster-$(date +%s)"
fi

echo "📋 Demo Configuration:"
echo "  Registry: ${LOCAL_REGISTRY}"
echo "  Image: ${FULL_IMAGE_REF}"
echo "  Snapshot: ${SNAPSHOT_NAME}"
echo ""

echo "🔧 Step 1: Setting up registry..."

if [ "$USE_CLUSTER_REGISTRY" = "true" ]; then
    echo "  Setting up in-cluster registry..."
    # Deploy in-cluster registry
    kubectl apply -f hack/vsa_generation_demo/in-cluster-registry.yaml
    
    # Wait for registry to be ready
    echo "  Waiting for in-cluster registry to be ready..."
    kubectl wait --for=condition=available --timeout=60s deployment/registry -n registry
    
    # Set up port-forward for external access
    echo "  Setting up port-forward for external registry access..."
    # Kill any existing port-forward on this port
    pkill -f "kubectl.*port-forward.*registry.*5001:5000" 2>/dev/null || true
    sleep 2
    
    # Start port-forward in background
    kubectl port-forward -n registry service/registry 5001:5000 > /dev/null 2>&1 &
    PORT_FORWARD_PID=$!
    
    # Store PID for cleanup
    echo "$PORT_FORWARD_PID" > /tmp/vsa-demo-port-forward.pid
    
    # Wait for port-forward to be ready
    echo "  Waiting for port-forward to be accessible..."
    for i in {1..30}; do
        if curl -s "http://${EXTERNAL_REGISTRY}/v2/" > /dev/null 2>&1; then
            echo "  Port-forward is accessible at ${EXTERNAL_REGISTRY}"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "  Warning: Port-forward not accessible after 30 attempts"
            echo "  This might cause image push failures"
        fi
        sleep 2
    done
    
    echo "  In-cluster registry ready at ${LOCAL_REGISTRY}"
    echo ""
    echo "📋 Registry Configuration:"
    echo "  ✅ In-cluster registry accessible from TaskRuns"
    echo "  ✅ External access via port-forward at ${EXTERNAL_REGISTRY}"
    echo "  ✅ This will demonstrate successful policy validation"
    echo "  💡 Images will be accessible from within the cluster"
    
elif [ "$USE_PUBLIC_IMAGE" = "true" ]; then
    echo "  Using public image (no local registry needed)..."
    echo ""
    echo "📋 Registry Configuration:"
    echo "  ✅ Using pre-signed public image"
    echo "  ✅ No local registry required"
    echo "  ✅ This will demonstrate successful policy validation"
    
else
    # Check if local registry is running, start if needed
    if ! curl -s http://localhost:5001/v2/ > /dev/null 2>&1; then
        echo "  Starting local Docker registry..."
        docker run -d --restart=always -p 5001:5000 --name vsa-demo-registry registry:2 || true
        sleep 3
        echo "  Registry started at ${LOCAL_REGISTRY}"
    else
        echo "  Registry already running at ${LOCAL_REGISTRY}"
    fi
    
    echo ""
    echo "📋 Registry Configuration:"
    echo "  ⚠️  The local registry (localhost:5001) is only accessible from the host machine."
    echo "  ✅ TaskRuns inside Kubernetes cannot access localhost registries."
    echo "  ✅ This demo will show VSA generation even when image accessibility fails."
    echo "  ✅ The VSA will be generated and uploaded to Rekor successfully."
    echo "  💡 In production, use accessible registries (quay.io, gcr.io, etc.)"
fi

echo ""

if [ "$USE_PUBLIC_IMAGE" = "true" ]; then
    echo ""
    echo "🏗️ Step 2: Using public image (skipping build)..."
    echo "  Using pre-signed image: ${FULL_IMAGE_REF}"
    FULL_IMAGE_WITH_DIGEST="${FULL_IMAGE_REF}"
else
    echo ""
    echo "🏗️ Step 2: Building test application..."
    cd hack/vsa_generation_demo/test-app
    
    if [ "$USE_CLUSTER_REGISTRY" = "true" ]; then
        # Build and tag for external registry (for pushing)
        EXTERNAL_IMAGE_REF="${EXTERNAL_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
        echo "  Building Docker image: ${EXTERNAL_IMAGE_REF}"
        docker build -t "${EXTERNAL_IMAGE_REF}" .
        echo "  Pushing to in-cluster registry via NodePort..."
        docker push "${EXTERNAL_IMAGE_REF}"
        
        # Get the image digest and convert to internal cluster address
        IMAGE_DIGEST=$(docker inspect "${EXTERNAL_IMAGE_REF}" --format='{{index .RepoDigests 0}}' | cut -d'@' -f2)
        FULL_IMAGE_WITH_DIGEST="${LOCAL_REGISTRY}/${IMAGE_NAME}@${IMAGE_DIGEST}"
        echo "  Image with digest (cluster-internal): ${FULL_IMAGE_WITH_DIGEST}"
    else
        # Original localhost registry logic
        echo "  Building Docker image: ${FULL_IMAGE_REF}"
        docker build -t "${FULL_IMAGE_REF}" .
        echo "  Pushing to local registry..."
        docker push "${FULL_IMAGE_REF}"

        # Get the image digest for the snapshot
        IMAGE_DIGEST=$(docker inspect "${FULL_IMAGE_REF}" --format='{{index .RepoDigests 0}}' | cut -d'@' -f2)
        FULL_IMAGE_WITH_DIGEST="${LOCAL_REGISTRY}/${IMAGE_NAME}@${IMAGE_DIGEST}"
        echo "  Image with digest: ${FULL_IMAGE_WITH_DIGEST}"
    fi

    # Return to project root
    cd "${PROJECT_ROOT}"
fi

# Set up demo keys directory for both modes
DEMO_KEYS_DIR="hack/vsa_generation_demo"

if [ "$USE_PUBLIC_IMAGE" = "true" ]; then
    echo ""
    echo "🔑 Step 3: Using existing signatures (skipping key generation)..."
    echo "  Public image is already signed with production keys"
    echo ""
    echo "✍️ Step 4: Using existing signatures (skipping signing)..."
    echo "  Image already signed and verified in production"
else
    echo ""
    echo "🔑 Step 3: Generating signing keys..."
    # Generate proper Sigstore keys for this demo (non-interactive)
    # Store keys in the demo directory to keep them contained
    DEMO_KEYS_DIR="hack/vsa_generation_demo"
    rm -f "${DEMO_KEYS_DIR}/vsa-demo-keys.key" "${DEMO_KEYS_DIR}/vsa-demo-keys.pub"  # Clean up any existing keys
    cd "${DEMO_KEYS_DIR}"
    COSIGN_PASSWORD="" cosign generate-key-pair --output-key-prefix vsa-demo-keys
    cd "${PROJECT_ROOT}"
    echo "  Generated ${DEMO_KEYS_DIR}/vsa-demo-keys.key and ${DEMO_KEYS_DIR}/vsa-demo-keys.pub"

    echo ""
    echo "✍️ Step 4: Signing the image..."
    
    if [ "$USE_CLUSTER_REGISTRY" = "true" ]; then
        # For cluster registry, sign using the external address but the same digest
        EXTERNAL_IMAGE_WITH_DIGEST="${EXTERNAL_REGISTRY}/${IMAGE_NAME}@${IMAGE_DIGEST}"
        echo "  Signing image via external address: ${EXTERNAL_IMAGE_WITH_DIGEST}"
        COSIGN_PASSWORD="" cosign sign --key "${DEMO_KEYS_DIR}/vsa-demo-keys.key" "${EXTERNAL_IMAGE_WITH_DIGEST}" --yes
        echo "  Image signed successfully"

        # Verify the signature
        echo "  Verifying signature..."
        cosign verify --key "${DEMO_KEYS_DIR}/vsa-demo-keys.pub" "${EXTERNAL_IMAGE_WITH_DIGEST}"
        echo "  Signature verified!"
        
        # Add SLSA attestations for complete policy compliance
        echo "  Creating SLSA provenance attestation for complete policy compliance..."
        IMAGE_DIGEST_ONLY=$(echo "${IMAGE_DIGEST}" | cut -d':' -f2)
        cat > /tmp/slsa-provenance-cluster.json << EOF
{
  "_type": "https://in-toto.io/Statement/v0.1",
  "predicateType": "https://slsa.dev/provenance/v0.2",
  "subject": [
    {
      "name": "${EXTERNAL_IMAGE_WITH_DIGEST}",
      "digest": {
        "sha256": "${IMAGE_DIGEST_ONLY}"
      }
    }
  ],
  "predicate": {
    "builder": {
      "id": "https://github.com/conforma/knative-service/demo-builder"
    },
    "buildType": "https://github.com/conforma/knative-service/demo-build",
    "invocation": {
      "configSource": {
        "uri": "https://github.com/conforma/knative-service",
        "digest": {
          "sha1": "demo-commit-hash"
        }
      }
    },
    "metadata": {
      "buildInvocationId": "demo-build-$(date +%s)",
      "buildStartedOn": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
      "buildFinishedOn": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
      "completeness": {
        "parameters": true,
        "environment": false,
        "materials": true
      },
      "reproducible": false
    },
    "materials": [
      {
        "uri": "https://github.com/conforma/knative-service",
        "digest": {
          "sha1": "demo-commit-hash"
        }
      }
    ]
  }
}
EOF
        COSIGN_PASSWORD="" cosign attest --key "${DEMO_KEYS_DIR}/vsa-demo-keys.key" --predicate /tmp/slsa-provenance-cluster.json "${EXTERNAL_IMAGE_WITH_DIGEST}" --yes
        echo "  SLSA provenance attestation created"
        
        # Verify the attestation
        echo "  Verifying attestation..."
        cosign verify-attestation --key "${DEMO_KEYS_DIR}/vsa-demo-keys.pub" "${EXTERNAL_IMAGE_WITH_DIGEST}"
        echo "  Attestation verified!"
        
        # Clean up
        rm -f /tmp/slsa-provenance-cluster.json
    else
        # Sign the image with our generated key
        COSIGN_PASSWORD="" cosign sign --key "${DEMO_KEYS_DIR}/vsa-demo-keys.key" "${FULL_IMAGE_WITH_DIGEST}" --yes
        echo "  Image signed successfully"

        # Verify the signature
        echo "  Verifying signature..."
        cosign verify --key "${DEMO_KEYS_DIR}/vsa-demo-keys.pub" "${FULL_IMAGE_WITH_DIGEST}"
        echo "  Signature verified!"
    fi
fi

echo ""
echo "🔧 Step 5: Setting up demo resources..."
# Check prerequisites (assume service is deployed via make deploy-local)
echo "  Checking prerequisites..."
if ! kubectl get task generate-vsa -n default > /dev/null 2>&1; then
    echo "  ⚠️  generate-vsa task not found. Please deploy the service first:"
    echo "     make deploy-local"
    exit 1
fi

if ! kubectl get serviceaccount conforma-vsa-generator -n default > /dev/null 2>&1; then
    echo "  ⚠️  conforma-vsa-generator service account not found. Please deploy the service first:"
    echo "     make deploy-local"
    exit 1
fi

echo "  ✅ Prerequisites satisfied (service appears to be deployed)"

echo "  Using default namespace with standard secret names (no ConfigMap changes needed)"

# Apply VSA demo specific resources (RPA, ECP, secrets)
echo "  Applying VSA demo resources..."
kubectl apply -f hack/vsa_generation_demo/vsa-demo-resources.yaml
echo "  Demo resources configured"

echo ""
echo "🔑 Step 6: Creating VSA signing key secrets..."

if [ "$USE_PUBLIC_IMAGE" = "true" ]; then
    echo "  Using existing public key secret (already created in resources)"
    # Create a dummy VSA signing key secret with standard name (required for TaskRun workspace)
    echo "  Creating dummy VSA signing key secret for TaskRun workspace..."
    kubectl create secret generic vsa-signing-key \
        --from-literal=cosign.key="dummy-key-not-used-for-public-images" \
        -n "${DEMO_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
    echo "  Dummy VSA signing key secret created"
else
    # Create signing key secret with standard name for TaskRun workspace
    kubectl create secret generic vsa-signing-key \
        --from-file=cosign.key="${DEMO_KEYS_DIR}/vsa-demo-keys.key" \
        -n "${DEMO_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
    echo "  VSA signing key secret created"

    # Create public key secret with standard name for policy validation
    kubectl create secret generic public-key \
        --from-file=cosign.pub="${DEMO_KEYS_DIR}/vsa-demo-keys.pub" \
        -n openshift-pipelines --dry-run=client -o yaml | kubectl apply -f -
    echo "  Public key secret created"
fi

if [ "$USE_PUBLIC_IMAGE" = "true" ]; then
    echo "  Using standard public key for public image demo..."
    # Use the actual public key from the golden container image
    PUBLIC_KEY_CONTENT="-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEZP/0htjhVt2y0ohjgtIIgICOtQtA
naYJRuLprwIv6FDhZ5yFjYUEtsmoNcW7rx2KM6FOXGsCX3BNc7qhHELT+g==
-----END PUBLIC KEY-----"
    
    kubectl create secret generic public-key \
        --from-literal=cosign.pub="$PUBLIC_KEY_CONTENT" \
        -n openshift-pipelines --dry-run=client -o yaml | kubectl apply -f -
    echo "  Standard public key secret created for public image"
fi

echo "  Using existing ConfigMap (no modifications needed for self-contained demo)"

echo ""
echo "📦 Step 7: Creating snapshot for VSA generation..."
# Create a temporary snapshot file
cat > /tmp/vsa-demo-snapshot.yaml << EOF
apiVersion: appstudio.redhat.com/v1alpha1
kind: Snapshot
metadata:
  name: ${SNAPSHOT_NAME}
  namespace: ${DEMO_NAMESPACE}
spec:
  application: vsa-demo-application
  displayName: ${SNAPSHOT_NAME}
  displayDescription: "Demo snapshot for VSA generation testing"
  components:
    - name: vsa-demo-component
      containerImage: "${FULL_IMAGE_WITH_DIGEST}"
EOF

echo "  Created snapshot: ${SNAPSHOT_NAME}"
echo "  Image: ${FULL_IMAGE_WITH_DIGEST}"

echo ""
echo "🚀 Step 8: Triggering VSA generation..."
kubectl apply -f /tmp/vsa-demo-snapshot.yaml
echo "  Snapshot applied - VSA generation should start"

echo ""
echo "⏳ Step 9: Monitoring VSA generation..."
echo "  Waiting for TaskRun creation..."
sleep 5

# Find the TaskRun in the demo namespace
TASKRUN=$(kubectl get taskruns -l app.kubernetes.io/instance=${SNAPSHOT_NAME} -n "${DEMO_NAMESPACE}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -z "$TASKRUN" ]; then
    echo "  ⚠️ No TaskRun found yet. Checking service logs..."
    kubectl logs -l app=conforma-knative-service -n default --tail=10
    echo ""
    echo "  💡 This might indicate:"
    echo "    - No ReleasePlan configured for vsa-demo-application"
    echo "    - Service is still processing the snapshot"
    echo "    - Check 'kubectl get taskruns' manually"
else
    echo "  ✅ TaskRun created: ${TASKRUN}"
    echo ""
    echo "📊 Step 10: Watching VSA generation progress..."
    echo "  Following TaskRun logs (Ctrl+C to exit):"
    echo "  Command: tkn taskrun logs -f ${TASKRUN}"
    echo ""
    echo "📋 Expected Behavior:"
    if [ "$USE_PUBLIC_IMAGE" = "true" ]; then
        echo "  ✅ Image accessibility will SUCCEED (public registry accessible)"
        echo "  ✅ Policy validation will SUCCEED"
        echo "  ✅ VSA will be GENERATED and uploaded to Rekor"
        echo "  ✅ This demonstrates successful VSA generation with passing policies"
    elif [ "$USE_CLUSTER_REGISTRY" = "true" ]; then
        echo "  ✅ Image accessibility will SUCCEED (in-cluster registry accessible)"
        echo "  ✅ Image signature check will SUCCEED"
        echo "  ✅ Attestation signature check will SUCCEED (SLSA provenance included)"
        echo "  ✅ Policy validation will SUCCEED (complete compliance)"
        echo "  ✅ VSA will be GENERATED and uploaded to Rekor"
        echo "  ✅ This demonstrates COMPLETE successful VSA generation!"
    else
        echo "  ✅ Image accessibility will FAIL (localhost registry not accessible from cluster)"
        echo "  ✅ Policy validation will show violations"
        echo "  ✅ VSA will still be GENERATED and uploaded to Rekor"
        echo "  ✅ This demonstrates VSA generation even with policy failures"
    fi
    echo ""
    echo "  Following TaskRun logs for 60 seconds..."
    timeout 60s tkn taskrun logs -f "${TASKRUN}" || echo "  Log following completed or timed out"
    
    echo ""
    echo "📊 Final TaskRun status:"
    kubectl get taskrun "${TASKRUN}" -o wide
fi

echo ""
echo "🧹 Cleanup (optional):"
echo "  To clean up demo resources:"
echo "    kubectl delete snapshot ${SNAPSHOT_NAME}"
echo "    kubectl delete secret vsa-demo-signing-key"
echo "    docker stop vsa-demo-registry && docker rm vsa-demo-registry"
echo "    rm -f vsa-demo-keys.key vsa-demo-keys.pub /tmp/vsa-demo-snapshot.yaml"
echo ""
echo "✅ VSA Generation Demo Complete!"
