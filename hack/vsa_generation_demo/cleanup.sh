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

echo "🧹 Manual Cleanup for VSA Generation Demo"
echo "Working from: $(pwd)"
echo "=========================================="
echo ""
echo "ℹ️  Note: The demo script now includes automatic cleanup."
echo "   This script provides manual cleanup for troubleshooting."
echo ""

# Clean up Kubernetes resources
echo "  Removing demo snapshots..."
kubectl delete snapshots -l demo=vsa-generation --ignore-not-found

echo "  Removing demo secrets..."
kubectl delete secret vsa-demo-signing-key --ignore-not-found -n default
kubectl delete secret vsa-demo-public-key --ignore-not-found -n openshift-pipelines

echo "  Removing demo resources..."
kubectl delete -f hack/vsa_generation_demo/vsa-demo-resources.yaml --ignore-not-found

# Clean up local files
DEMO_KEYS_DIR="hack/vsa_generation_demo"
echo "  Removing generated keys..."
rm -f "${DEMO_KEYS_DIR}/vsa-demo-keys.key" "${DEMO_KEYS_DIR}/vsa-demo-keys.pub"

echo "  Removing temporary files..."
rm -f /tmp/vsa-demo-snapshot.yaml

# Clean up Docker registry
echo "  Stopping local registry..."
docker stop vsa-demo-registry 2>/dev/null || true
docker rm vsa-demo-registry 2>/dev/null || true

# Clean up local images
echo "  Removing demo images..."
docker images --format "table {{.Repository}}:{{.Tag}}" | grep "localhost:5001/vsa-demo-app" | xargs -r docker rmi || true

echo ""
echo "✅ VSA Generation Demo cleanup complete!"
echo ""
echo "💡 To restore original demo configuration:"
echo "   kubectl patch configmap taskrun-config -n default --patch '{"
echo "     \"data\": {"
echo "       \"VSA_SIGNING_KEY_SECRET_NAME\": \"vsa-signing-key\","
echo "       \"PUBLIC_KEY\": \"k8s://openshift-pipelines/public-key\""
echo "     }"
echo "   }'"
