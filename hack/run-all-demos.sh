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

echo "🎯 Conforma VSA Demo Suite - Complete Walkthrough"
echo "================================================="
echo "This script runs all demos consecutively to show the complete"
echo "VSA generation and validation capabilities of Conforma."
echo ""

# Function to run a demo with proper isolation
run_demo_with_reset() {
    local demo_name="$1"
    local demo_command="$2"
    
    echo ""
    echo "🚀 Running: $demo_name"
    echo "$(printf '=%.0s' {1..50})"
    echo ""
    
    # Run the demo
    eval "$demo_command"
    
    echo ""
    echo "✅ $demo_name completed"
    echo ""
    echo "🔄 Resetting environment for next demo..."
    ./hack/reset-demo-environment.sh
    
    echo ""
    echo "⏳ Waiting 10 seconds before next demo..."
    sleep 10
}

echo "📋 Demo Sequence:"
echo "1. VSA Validation Demo (shows intelligent VSA reuse)"
echo "2. VSA Generation - Localhost Mode (shows resilient generation)"  
echo "3. VSA Generation - Cluster Mode (shows complete success)"
echo "4. VSA Generation - Public Mode (shows VSA discovery)"
echo ""

read -p "Press Enter to start the demo sequence (or Ctrl+C to cancel)..."

# Reset environment first
echo ""
echo "🔄 Initial environment reset..."
./hack/reset-demo-environment.sh

# Run all demos with proper isolation
run_demo_with_reset "VSA Validation Demo" "./hack/vsa_validation_demo/demo-vsa-validation.sh"

run_demo_with_reset "VSA Generation - Localhost Mode" "./hack/vsa_generation_demo/run-demo.sh localhost"

run_demo_with_reset "VSA Generation - Cluster Mode" "./hack/vsa_generation_demo/run-demo.sh cluster"

run_demo_with_reset "VSA Generation - Public Mode" "./hack/vsa_generation_demo/run-demo.sh public"

echo ""
echo "🎉 All Demos Completed Successfully!"
echo "===================================="
echo ""
echo "📊 Summary of what was demonstrated:"
echo "  ✅ VSA Validation: Intelligent reuse of existing VSAs"
echo "  ✅ VSA Generation (Localhost): Resilient generation despite failures"
echo "  ✅ VSA Generation (Cluster): Complete success with attestations"
echo "  ✅ VSA Generation (Public): VSA discovery and optimization"
echo ""
echo "🔗 All VSAs were uploaded to Rekor transparency log for auditability"
echo "🧹 Environment has been reset and is ready for individual demo runs"
echo ""
