#!/usr/bin/env bash
set -euo pipefail

# This is a convenience wrapper for running hack/test_ecp_lookup.go to
# test/debug RPA/ECP lookups in a real cluster.

# You need to be logged in to our Konflux cluster. If not then go here
# to get an `oc login` command with a token then run it:
#   https://oauth-openshift.apps.stone-prd-rh01.pg1f.p1.openshiftapps.com/oauth/token/request

# Find a recent snapshot that starts with "ec-v".
# We're dog-fooding our own Conforma cli Konflux builds here, and I know the
# ec-v0{5,6,7} applications definitely have an RPA.
NAMESPACE=rhtap-contract-tenant
SNAPSHOT=$(oc get snapshot -n $NAMESPACE \
  --sort-by=.metadata.creationTimestamp --no-headers \
  --output=custom-columns="NAME:.metadata.name" |
  grep ^ec-v |
  tail -1)

# Use the test go program to look up the ECP for that snapshot
go run hack/test_ecp_lookup.go $SNAPSHOT $NAMESPACE
