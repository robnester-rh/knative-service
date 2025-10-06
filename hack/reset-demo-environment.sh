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
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

echo "🔄 Resetting Demo Environment"
echo "============================="
echo "This script cleans up all demo resources to ensure"
echo "consecutive demo runs don't interfere with each other."
echo ""

# 1. Reset ConfigMap to default state
echo "📋 Step 1: Resetting ConfigMap to default state..."
kubectl patch configmap taskrun-config -n default --patch '{
    "data": {
        "POLICY_CONFIGURATION": "github.com/enterprise-contract/config//slsa3",
        "PUBLIC_KEY": "k8s://openshift-pipelines/public-key",
        "IGNORE_REKOR": "true",
        "VSA_SIGNING_KEY_SECRET_NAME": "vsa-signing-key",
        "VSA_UPLOAD_URL": "rekor@https://rekor.sigstore.dev",
        "TASK_NAME": "generate-vsa"
    }
}' 2>/dev/null || echo "  ConfigMap not found (will be created by demos)"

# 2. Clean up all demo snapshots
echo "📦 Step 2: Cleaning up demo snapshots..."
kubectl delete snapshots --all -n default --ignore-not-found 2>/dev/null || true

# 3. Clean up all demo secrets
echo "🔑 Step 3: Cleaning up demo secrets..."
kubectl delete secrets \
    vsa-demo-signing-key \
    vsa-complete-demo-signing-key \
    vsa-signing-key \
    --ignore-not-found -n default 2>/dev/null || true

kubectl delete secrets \
    vsa-demo-public-key \
    vsa-complete-demo-public-key \
    public-key \
    --ignore-not-found -n openshift-pipelines 2>/dev/null || true

# 4. Clean up demo namespaces
echo "🏢 Step 4: Cleaning up demo namespaces..."
kubectl delete namespace rhtap-releng-tenant --ignore-not-found 2>/dev/null || true
kubectl delete namespace openshift-pipelines --ignore-not-found 2>/dev/null || true
kubectl delete namespace registry --ignore-not-found 2>/dev/null || true

# 5. Clean up Tekton resources
echo "⚙️  Step 5: Cleaning up Tekton resources..."
kubectl delete task generate-vsa --ignore-not-found -n default 2>/dev/null || true

# 6. Clean up RBAC resources
echo "🔐 Step 6: Cleaning up RBAC resources..."
kubectl delete serviceaccount conforma-vsa-generator --ignore-not-found -n default 2>/dev/null || true
kubectl delete role conforma-vsa-generator --ignore-not-found -n default 2>/dev/null || true
kubectl delete rolebinding conforma-vsa-generator --ignore-not-found -n default 2>/dev/null || true
kubectl delete clusterrole conforma-vsa-generator-cluster --ignore-not-found 2>/dev/null || true
kubectl delete clusterrolebinding conforma-vsa-generator-cluster --ignore-not-found 2>/dev/null || true

# 7. Clean up Docker resources
echo "🐳 Step 7: Cleaning up Docker resources..."
docker stop vsa-demo-registry 2>/dev/null || true
docker rm vsa-demo-registry 2>/dev/null || true

# Kill any port-forwards
pkill -f "kubectl.*port-forward.*registry" 2>/dev/null || true

# 8. Clean up temporary files
echo "📁 Step 8: Cleaning up temporary files..."
rm -f /tmp/vsa-demo-*.yaml 2>/dev/null || true
rm -f /tmp/vsa-complete-demo-*.yaml 2>/dev/null || true
rm -f /tmp/slsa-provenance*.json 2>/dev/null || true
rm -f /tmp/vsa-*-port-forward.pid 2>/dev/null || true

# 9. Clean up generated keys
echo "🔑 Step 9: Cleaning up generated keys..."
rm -f hack/vsa_generation_demo/vsa-demo-keys.* 2>/dev/null || true
rm -f hack/vsa_generation_demo/vsa-complete-demo-keys.* 2>/dev/null || true

# 10. Clean up old TaskRuns
echo "🧹 Step 10: Cleaning up old TaskRuns..."
kubectl get taskruns -n default --no-headers -o custom-columns=":metadata.name" 2>/dev/null | \
    grep -E '^verify-conforma-' | \
    head -10 | \
    xargs -r kubectl delete taskrun -n default 2>/dev/null || true

echo ""
echo "✅ Demo environment reset complete!"
echo ""
echo "🚀 You can now run any demo without conflicts:"
echo "  ./hack/vsa_generation_demo/run-demo.sh <mode>"
echo "  ./hack/vsa_validation_demo/demo-vsa-validation.sh"
echo ""
