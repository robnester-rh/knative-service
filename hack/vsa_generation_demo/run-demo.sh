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

echo "🚀 VSA Generation Demo Runner"
echo "=============================="
echo ""

# Show usage if no arguments or help requested
if [ $# -eq 0 ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    echo "Usage: $0 <mode>"
    echo ""
    echo "Available modes:"
    echo "  localhost    - Use localhost registry (shows expected failures)"
    echo "  cluster      - Use in-cluster registry (shows successful validation)"
    echo "  public       - Use public image (shows successful validation)"
    echo "  complete     - Complete success demo with attestations (shows FULL SUCCESS)"
    echo ""
    echo "Examples:"
    echo "  $0 localhost   # Default mode - demonstrates resilient VSA generation"
    echo "  $0 cluster     # In-cluster registry - demonstrates successful validation"
    echo "  $0 public      # Public image - demonstrates VSA reuse"
    echo "  $0 complete    # Complete success - demonstrates FULL policy compliance"
    echo ""
    exit 0
fi

MODE="$1"

case "$MODE" in
    "localhost")
        echo "📋 Running demo with localhost registry (expected failures)"
        echo "  This demonstrates VSA generation even when images are not accessible"
        echo ""
        ./hack/vsa_generation_demo/demo-vsa-generation.sh
        ;;
    "cluster")
        echo "📋 Running demo with in-cluster registry (successful validation)"
        echo "  This demonstrates successful VSA generation with accessible images"
        echo ""
        USE_CLUSTER_REGISTRY=true ./hack/vsa_generation_demo/demo-vsa-generation.sh
        ;;
    "public")
        echo "📋 Running demo with public image (successful validation)"
        echo "  This demonstrates VSA reuse when valid VSAs already exist"
        echo ""
        USE_PUBLIC_IMAGE=true ./hack/vsa_generation_demo/demo-vsa-generation.sh
        ;;
    "complete")
        echo "📋 Running complete success demo (FULL policy compliance)"
        echo "  This demonstrates complete end-to-end success with attestations"
        echo ""
        ./hack/vsa_generation_demo/demo-complete-success.sh
        ;;
    *)
        echo "❌ Unknown mode: $MODE"
        echo ""
        echo "Available modes: localhost, cluster, public, complete"
        echo "Run '$0 --help' for more information"
        exit 1
        ;;
esac
