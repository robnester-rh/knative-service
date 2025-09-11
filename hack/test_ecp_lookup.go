// ---------------------------------------------------------------------------
//
// This is meant to be a thin wrapper for the FindECP function in
// cmd/launch-taskrun/konflux/ecp_lookup so you can run it directly.
// It maybe doesn't have a lot of long term value, and it has no test
// coverage, but it's useful when developing and debugging the FindECP
// function from cmd/launch-taskrun/konflux/ecp_lookup.go.
//
// Example usage:
//   $ go run hack/ecp_lookup.go ec-v07-psx6j rhtap-contract-tenant
//
// Or use this bash script:
//   $ ./hack/test_ecp_lookup.sh
//
// ---------------------------------------------------------------------------

package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"

	"sigs.k8s.io/controller-runtime/pkg/client"

	"github.com/conforma/conforma-verifier-listener/cmd/launch-taskrun/k8s"
	"github.com/conforma/conforma-verifier-listener/cmd/launch-taskrun/konflux"
)

func main() {
	if len(os.Args) < 3 {
		log.Fatalf("Usage: go run test_ecp_lookup.go <snapshot-name> <namespace>")
	}

	snapshotName := os.Args[1]
	namespace := os.Args[2]

	// Create client
	cli, err := k8s.NewControllerRuntimeClient()
	if err != nil {
		log.Fatalf("Failed to create client: %v", err)
	}

	// Get the snapshot
	snapshot := &konflux.Snapshot{}
	err = cli.Get(context.Background(), client.ObjectKey{
		Name:      snapshotName,
		Namespace: namespace,
	}, snapshot)
	if err != nil {
		log.Fatalf("Failed to get snapshot %s/%s: %v", namespace, snapshotName, err)
	}

	fmt.Printf("Found snapshot: %s\n", snapshot.Name)

	// Extract application name from raw JSON spec
	var spec struct {
		Application string `json:"application"`
	}
	if err = json.Unmarshal(snapshot.Spec, &spec); err != nil {
		log.Fatalf("Failed to extract application from spec: %v", err)
	}
	fmt.Printf("Application name: %s\n", spec.Application)

	// Call FindEnterpriseContractPolicy
	policyResult, err := konflux.FindEnterpriseContractPolicy(context.Background(), cli, snapshot)
	if err != nil {
		log.Fatalf("Failed to get enterprise contract policy: %v", err)
	}

	fmt.Printf("Found ECP name: %s\n", policyResult)
}
