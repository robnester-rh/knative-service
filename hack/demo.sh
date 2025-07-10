#!/usr/bin/env bash
set -euo pipefail

echo "* Deleting old snapshot..."
kubectl delete --ignore-not-found -f test-snapshot.yaml

echo "* Creating new snapshot..."
kubectl create -f test-snapshot.yaml

echo "* A little wait..."
sleep 3

echo "* Find the new taskrun..."
TASKRUN=$(tkn tr list -o yaml | yq '.items[0].metadata.name')
echo $TASKRUN

# Watch the logs of that taskrun
echo "* Watch the taskrun logs..."
tkn taskrun logs -f $TASKRUN
