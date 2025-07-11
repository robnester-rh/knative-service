#!/usr/bin/env bash
set -euo pipefail

LABEL="$1"
NAMESPACE="$2"

# Wait for pod to be created
while ! kubectl get pod -l "$LABEL" -n "$NAMESPACE" --no-headers 2>/dev/null | grep -q .; do
  echo -n "."
  sleep 2
done

# Wait for pod to be ready
kubectl wait --for=condition=ready pod -l "$LABEL" -n "$NAMESPACE" --timeout 300s
