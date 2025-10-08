#!/usr/bin/env bash
# Copyright The Conforma Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

set -euo pipefail

# Usage: wait-for-resources.sh <resource-type> <condition> <timeout> <resource-names...>
# Examples:
#   wait-for-resources.sh crd established 60s releaseplans.appstudio.redhat.com releaseplanadmissions.appstudio.redhat.com
#   wait-for-resources.sh pod ready 300s -l app=myapp -n default

RESOURCE_TYPE="$1"
CONDITION="$2"
TIMEOUT="$3"
shift 3

echo "Waiting for $RESOURCE_TYPE resources to be $CONDITION (timeout: $TIMEOUT)..."

# Build the kubectl wait command based on argument types
if [[ "$1" == -* ]]; then
    # Arguments start with flags (like -l, -n) - use them directly
    echo -n "  $*: "
    kubectl_args=("$RESOURCE_TYPE" "$@")
else
    # Arguments are resource names - prefix each with resource type
    resource_list=()
    for resource in "$@"; do
        resource_list+=("$RESOURCE_TYPE/$resource")
    done
    echo -n "  ${resource_list[*]}: "
    kubectl_args=("${resource_list[@]}")
fi

if kubectl wait --for="condition=$CONDITION" "${kubectl_args[@]}" --timeout="$TIMEOUT" 2>/dev/null; then
    echo "✓"
else
    echo "✗ (timeout or error)"
    exit 1
fi

echo "All $RESOURCE_TYPE resources are $CONDITION!"
