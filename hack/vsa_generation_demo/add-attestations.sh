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

echo "🎯 Adding SLSA Attestations to Existing Image"
echo "============================================="

if [ $# -ne 2 ]; then
    echo "Usage: $0 <image-with-digest> <signing-key-path>"
    echo "Example: $0 localhost:5001/app@sha256:abc123 ./keys/demo.key"
    exit 1
fi

IMAGE_WITH_DIGEST="$1"
SIGNING_KEY="$2"

echo "📋 Configuration:"
echo "  Image: ${IMAGE_WITH_DIGEST}"
echo "  Signing Key: ${SIGNING_KEY}"
echo ""

# Extract digest for SLSA provenance
IMAGE_DIGEST=$(echo "${IMAGE_WITH_DIGEST}" | cut -d'@' -f2 | cut -d':' -f2)

echo "📋 Step 1: Creating SLSA provenance attestation..."
# Create a simple SLSA provenance attestation
cat > /tmp/slsa-provenance-addon.json << EOF
{
  "_type": "https://in-toto.io/Statement/v0.1",
  "predicateType": "https://slsa.dev/provenance/v0.2",
  "subject": [
    {
      "name": "${IMAGE_WITH_DIGEST}",
      "digest": {
        "sha256": "${IMAGE_DIGEST}"
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

echo "  Creating SLSA provenance attestation..."
COSIGN_PASSWORD="" cosign attest --key "${SIGNING_KEY}" --predicate /tmp/slsa-provenance-addon.json "${IMAGE_WITH_DIGEST}" --yes
echo "  ✅ SLSA provenance attestation created successfully"

# Verify the attestation
echo "  Verifying attestation..."
SIGNING_KEY_PUB="${SIGNING_KEY%.*}.pub"
cosign verify-attestation --key "${SIGNING_KEY_PUB}" "${IMAGE_WITH_DIGEST}"
echo "  ✅ Attestation verified!"

# Clean up
rm -f /tmp/slsa-provenance-addon.json

echo ""
echo "🎉 Attestations added successfully!"
echo "  The image now has both signatures and SLSA provenance attestations"
echo "  This should result in successful policy validation"
