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

echo "🧹 Manual Cleanup for VSA Validation Demo"
echo "Working from: $(pwd)"
echo "=========================================="
echo ""
echo "ℹ️  Note: The demo script now includes automatic cleanup."
echo "   This script provides manual cleanup for troubleshooting."
echo ""

# Clean up Kubernetes resources
echo "  Removing demo snapshots..."
kubectl delete snapshot vsa-validation-demo-snapshot --ignore-not-found -n default 2>/dev/null || true

echo "  Removing demo resources..."
kubectl delete -f hack/vsa_validation_demo/validation-demo-resources.yaml --ignore-not-found 2>/dev/null || true

echo "  Removing old TaskRuns..."
kubectl get taskruns -n default --no-headers -o custom-columns=":metadata.name,:metadata.creationTimestamp" 2>/dev/null | \
    awk '$2 < "'$(date -d '2 hours ago' -u +%Y-%m-%dT%H:%M:%SZ)'" {print $1}' | \
    grep -E '^verify-enterprise-contract-' | \
    xargs -r kubectl delete taskrun -n default 2>/dev/null || true

echo ""
echo "✅ Manual validation demo cleanup completed"
echo ""
echo "🔍 Remaining resources:"
echo "  Snapshots: $(kubectl get snapshots -n default --no-headers 2>/dev/null | wc -l)"
echo "  TaskRuns: $(kubectl get taskruns -n default --no-headers 2>/dev/null | wc -l)"

