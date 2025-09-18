#!/usr/bin/env bash
set -euo pipefail

echo "* Deleting old snapshot..."
kubectl delete --ignore-not-found -f test-snapshot.yaml

echo "* Creating new snapshot..."
kubectl create -f test-snapshot.yaml

echo "* Waiting for listener pod"
until kubectl get pod -l serving.knative.dev/service=conforma-verifier-listener -n default &>/dev/null; do sleep 1; done
kubectl wait --for=condition=Ready pod -l serving.knative.dev/service=conforma-verifier-listener -n default --timeout=30s

echo "* Showing listener pod logs"
sleep 2
kubectl logs -l serving.knative.dev/service=conforma-verifier-listener -n default -c user-container --tail 100

echo "* Find the new taskrun..."
sleep 2
TASKRUN=$(tkn tr list -o yaml | yq '.items[0].metadata.name')
echo $TASKRUN

# Watch the logs of that taskrun
echo "* Watch the taskrun logs (ctrl-c to quit)"
tkn taskrun logs -f $TASKRUN
