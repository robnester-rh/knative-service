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

echo "* Deleting old snapshot..."
kubectl delete --ignore-not-found -f test-snapshot.yaml

echo "* Creating new snapshot..."
kubectl create -f test-snapshot.yaml

echo "* Waiting for pod"
until kubectl get pod -l serving.knative.dev/service=conforma-knative-service -n default &>/dev/null; do sleep 1; done
kubectl wait --for=condition=Ready pod -l serving.knative.dev/service=conforma-knative-service -n default --timeout=30s

echo "* Showing pod logs"
sleep 2
kubectl logs -l serving.knative.dev/service=conforma-knative-service -n default -c user-container --tail 100

echo "* Find the new taskrun..."
sleep 2
TASKRUN=$(tkn tr list -o yaml | yq '.items[0].metadata.name')
echo $TASKRUN

# Watch the logs of that taskrun
echo "* Watch the taskrun logs (ctrl-c to quit)"
tkn taskrun logs -f $TASKRUN
