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
cleanup_validation_demo() {
    echo ""
    echo "🧹 Cleaning up VSA validation demo resources..."
    
    # Remove demo snapshots
    kubectl delete snapshot test-snapshot --ignore-not-found -n default 2>/dev/null || true
    
    # Remove demo resources (using dynamic file)
    kubectl delete -f /tmp/validation-demo-resources.yaml --ignore-not-found 2>/dev/null || true
    rm -f /tmp/validation-demo-resources.yaml 2>/dev/null || true
    
    # Remove the generate-vsa Tekton task
    kubectl delete -f config/base/generate-vsa.yaml --ignore-not-found 2>/dev/null || true
    
    # Remove RBAC for task runner
    kubectl delete -f config/base/task-runner-rbac.yaml --ignore-not-found 2>/dev/null || true
    
    # Clean up old TaskRuns created by this demo (keep recent ones, remove old ones)
    kubectl get taskruns -n default --no-headers -o custom-columns=":metadata.name,:metadata.creationTimestamp" 2>/dev/null | \
        awk '$2 < "'$(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ)'" {print $1}' | \
        grep -E '^verify-enterprise-contract-' | \
        head -5 | \
        xargs -r kubectl delete taskrun -n default 2>/dev/null || true
    
    echo "  Validation demo cleanup completed"
}

# Set up signal handlers for graceful cleanup
trap cleanup_validation_demo EXIT
trap 'echo ""; echo "🛑 Demo interrupted - cleaning up..."; cleanup_validation_demo; exit 1' INT TERM

echo "🔍 VSA Validation Demo"
echo "Working from: $(pwd)"
echo ""

# Clean up any conflicting resources from previous demos
echo "* Cleaning up any existing demo resources..."
kubectl delete namespace rhtap-releng-tenant openshift-pipelines --ignore-not-found 2>/dev/null || true
kubectl delete task generate-vsa --ignore-not-found -n default 2>/dev/null || true
kubectl delete serviceaccount conforma-vsa-generator --ignore-not-found -n default 2>/dev/null || true
kubectl delete clusterrole conforma-vsa-generator-cluster --ignore-not-found 2>/dev/null || true
kubectl delete clusterrolebinding conforma-vsa-generator-cluster --ignore-not-found 2>/dev/null || true

# Use unique resource names to avoid conflicts with generation demo
VALIDATION_DEMO_PREFIX="validation-$(date +%s)"
echo "* Using validation demo prefix: ${VALIDATION_DEMO_PREFIX}"
sleep 2

# Check if Tekton Pipelines is installed, install if needed
if ! kubectl get crd tasks.tekton.dev > /dev/null 2>&1; then
    echo "* Installing Tekton Pipelines..."
    kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml > /dev/null 2>&1
    echo "* Waiting for Tekton Pipelines to be ready..."
    kubectl wait --for=condition=ready pod -l app=tekton-pipelines-controller -n tekton-pipelines --timeout=300s > /dev/null 2>&1
    echo "* Tekton Pipelines installed"
else
    echo "* Tekton Pipelines already installed"
fi

echo "* Installing official CRDs (ReleasePlan, ReleasePlanAdmission, EnterpriseContractPolicy)..."
kubectl apply \
  -f https://raw.githubusercontent.com/konflux-ci/application-api/refs/heads/main/manifests/application-api-customresourcedefinitions.yaml \
  -f https://raw.githubusercontent.com/konflux-ci/release-service/refs/heads/main/config/crd/bases/appstudio.redhat.com_releaseplanadmissions.yaml \
  -f https://raw.githubusercontent.com/konflux-ci/release-service/refs/heads/main/config/crd/bases/appstudio.redhat.com_releaseplans.yaml \
  -f https://raw.githubusercontent.com/conforma/crds/refs/heads/main/config/crd/bases/appstudio.redhat.com_enterprisecontractpolicies.yaml

echo "* Waiting for CRDs to be ready..."
./hack/wait-for-resources.sh crd established 60s snapshots.appstudio.redhat.com releaseplans.appstudio.redhat.com releaseplanadmissions.appstudio.redhat.com enterprisecontractpolicies.appstudio.redhat.com

# Apply the generate-vsa Tekton task (required for VSA generation)
echo "* Installing generate-vsa Tekton task..."
kubectl apply -f config/base/generate-vsa.yaml
echo "* Tekton task installed"

# Apply RBAC for task runner (required for cross-namespace access)
echo "* Installing RBAC for task runner..."
kubectl apply -f config/base/task-runner-rbac.yaml
echo "* Task runner RBAC installed"

echo "* Creating validation demo resources with unique names..."
# Create dynamic validation demo resources to avoid conflicts
cat > /tmp/validation-demo-resources.yaml << EOF
---
# Namespace for the ReleasePlanAdmission (if it doesn't exist)
apiVersion: v1
kind: Namespace
metadata:
  name: ${VALIDATION_DEMO_PREFIX}-tenant
---
# ReleasePlanAdmission - defines the policy for releases
apiVersion: appstudio.redhat.com/v1alpha1
kind: ReleasePlanAdmission
metadata:
  name: ${VALIDATION_DEMO_PREFIX}-rpa
  namespace: ${VALIDATION_DEMO_PREFIX}-tenant
spec:
  applications:
    - application-sample
  origin: demo
  policy: ${VALIDATION_DEMO_PREFIX}-policy
---
# ReleasePlan - connects the application to the release process
apiVersion: appstudio.redhat.com/v1alpha1
kind: ReleasePlan
metadata:
  name: ${VALIDATION_DEMO_PREFIX}-release-plan
  namespace: default
  labels:
    release.appstudio.openshift.io/releasePlanAdmission: ${VALIDATION_DEMO_PREFIX}-rpa
spec:
  application: application-sample
  target: ${VALIDATION_DEMO_PREFIX}-tenant
---
# EnterpriseContractPolicy - defines the contract policy
apiVersion: appstudio.redhat.com/v1alpha1
kind: EnterpriseContractPolicy
metadata:
  name: ${VALIDATION_DEMO_PREFIX}-policy
  namespace: ${VALIDATION_DEMO_PREFIX}-tenant
spec:
  description: "Demo Enterprise Contract Policy"
  publicKey: "k8s://openshift-pipelines/public-key"
---
# Namespace for the public key secret
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-pipelines
---
# Demo public key secret (this would normally contain a real public key)
apiVersion: v1
kind: Secret
metadata:
  name: public-key
  namespace: openshift-pipelines
type: Opaque
data:
  # This is a valid Cosign public key for demo purposes
  cosign.pub: LS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS0KTUZrd0V3WUhLb1pJemowQ0FRWUlLb1pJemowREFRY0RRZ0FFWlAvMGh0amhWdDJ5MG9oamd0SUlnSUNPdFF0QQpuYVlKUnVMcHJ3SXY2RkRoWjV5RmpZVUV0c21vTmNXN3J4MktNNkZPWEdzQ1gzQk5jN3FoSEVMVCtnPT0KLS0tLS1FTkQgUFVCTElDIEtFWS0tLS0tCg==
---
# VSA signing key secret (for TaskRun workspace)
apiVersion: v1
kind: Secret
metadata:
  name: vsa-signing-key
  namespace: default
type: Opaque
data:
  # Demo private key (corresponding to the public key above)
  cosign.key: LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JR0hBZ0VBTUJNR0J5cUdTTTQ5QWdFR0NDcUdTTTQ5QXdFSEJHMHdhUUlCQVFRZ1pQL2h0amhWdDJ5MG9oamdKCnRJSWdJQ090UXRBbmFZSlJ1THByd0l2NkZEaGhaUmFoUkFOQ0FBUmsvL1NHMk9GVzNiTFNpR09DbWdpQWdJNjEKQzBDZHBnbEc0dW12QWkvb1VPRm5uSVdOaFFTMnlhZzF4YnV2SFlvem9VNWNhd0pmY0UxenVxRWNRdFA2Zz09Ci0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0K
EOF

kubectl apply -f /tmp/validation-demo-resources.yaml

echo "* Waiting for resources to be ready..."
sleep 2

echo "* Deleting old snapshot..."
kubectl delete --ignore-not-found -f test-snapshot.yaml

echo "* Creating new snapshot..."
kubectl create -f test-snapshot.yaml

echo "* Waiting for pod"
./hack/wait-for-resources.sh pod Ready 30s -l app=conforma-knative-service -n default

echo "* Showing pod logs"
sleep 2
kubectl logs -l app=conforma-knative-service -n default --tail 100

echo "* Checking for created resources..."
echo "ReleasePlans:"
kubectl get releaseplan -n default
echo ""
echo "ReleasePlanAdmissions:"
kubectl get releaseplanadmission -n rhtap-releng-tenant
echo ""
echo "EnterpriseContractPolicies:"
kubectl get enterprisecontractpolicy -n rhtap-releng-tenant
echo ""

echo "* Find the new taskrun..."
sleep 2
TASKRUN=$(tkn tr list -o yaml | yq '.items[0].metadata.name')
echo "TaskRun name: $TASKRUN"

if [ "$TASKRUN" = "null" ] || [ -z "$TASKRUN" ]; then
    echo "No TaskRuns found. This might be expected if:"
    echo "  - No ReleasePlan exists in the cluster"
    echo "  - The snapshot doesn't meet the criteria for TaskRun creation"
    echo "  - The service is configured to skip TaskRun creation"
    echo ""
    echo "Check the service logs above for more details."
    echo ""
    echo "Current TaskRuns in all namespaces:"
    kubectl get taskruns --all-namespaces
    exit 0
fi

# Watch the logs of that taskrun
echo "* Watch the taskrun logs (ctrl-c to quit)"
echo "  TaskRun: ${TASKRUN}"
echo "  Following logs for 30 seconds..."
timeout 30s tkn taskrun logs -f "${TASKRUN}" || echo "  Log following completed or timed out"

echo ""
echo "* Final TaskRun status:"
kubectl get taskrun "${TASKRUN}" -o wide
