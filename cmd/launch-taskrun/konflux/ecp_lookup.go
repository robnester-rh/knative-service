package konflux

import (
	"context"
	"encoding/json"
	"fmt"

	"sigs.k8s.io/controller-runtime/pkg/client"
)

// findReleasePlan looks for a release plan applicable for a given application
func FindReleasePlan(ctx context.Context, cli client.Client, appName string, ns string) (ReleasePlan, error) {
	var rp ReleasePlan

	// Get all release plans in the namespace
	planList := &ReleasePlanList{}
	err := cli.List(ctx, planList, client.InNamespace(ns))
	if err != nil {
		return rp, fmt.Errorf("failed to lookup release plan in namespace %s: %w", ns, err)
	}
	if len(planList.Items) == 0 {
		return rp, fmt.Errorf("no release plans found in namespace %s", ns)
	}

	// Filter to find just the release plans for the given application
	var matchingPlans []ReleasePlan
	for _, plan := range planList.Items {
		if plan.Spec.Application == appName {
			matchingPlans = append(matchingPlans, plan)
		}
	}
	if len(matchingPlans) == 0 {
		return rp, fmt.Errorf("no release plans found for application name: %s", appName)
	}

	// Choose one of the release plans
	// TODO: I'm expecting most of the time there will be only one releasePlan, but
	// I'm not sure how correct that is. Could there be more than one? If there was
	// more than one, how would we know which one to choose?
	rp = matchingPlans[0]

	return rp, nil
}

func FindReleasePlanAdmission(ctx context.Context, cli client.Client, rp ReleasePlan) (ReleasePlanAdmission, error) {
	// The RP points to a one specific RPA. Look it up using the target and a label value:
	var rpa ReleasePlanAdmission
	rpaKey := client.ObjectKey{
		Namespace: rp.Spec.Target, // usually "rhtap-releng-tenant"
		Name:      rp.Labels["release.appstudio.openshift.io/releasePlanAdmission"],
	}
	err := cli.Get(ctx, rpaKey, &rpa)
	if err != nil {
		return rpa, fmt.Errorf("failed to get release plan admission %s/%s: %w", rpaKey.Namespace, rpaKey.Name, err)
	}
	return rpa, nil
}

// FindECP takes a snapshot and tries to find the ECP that would be applicable in the
// Konflux release pipeline if that snapshot was released by looking up the relevant RPA
func FindEnterpriseContractPolicy(ctx context.Context, cli client.Client, snapshot *Snapshot) (string, error) {
	// TODO: There might be a way to look this up which would be preferable to hard-coding it here
	const defaultEcpName = "registry-standard"

	// Extract the application name from the raw JSON spec
	var spec struct {
		Application string `json:"application"`
	}
	if err := json.Unmarshal(snapshot.Spec, &spec); err != nil {
		return "", fmt.Errorf("failed to unmarshal snapshot spec to extract application: %w", err)
	}

	appName := spec.Application
	ns := snapshot.Namespace

	// Find the applicable ReleasePlan for this application
	rp, err := FindReleasePlan(ctx, cli, appName, ns)
	if err != nil {
		return "", err
	}

	// Use the ReleasePlan to find the relevant ReleasePlanAdmission
	rpa, err := FindReleasePlanAdmission(ctx, cli, rp)
	if err != nil {
		return "", err
	}

	// Read the ECP name from the ReleasePlanAdmission
	ecpName := rpa.Spec.Policy

	// TODO: It is safe to assume the RPA and the ECP are always in the same namespace?
	ecpNamespace := rpa.Namespace

	// Fall back to the default value if the RPA doesn't set a policy
	if ecpName == "" {
		ecpName = defaultEcpName
	}

	// Example value: rhtap-releng-tenant/registry-rhtap-contract
	// Conforma can use this directly with its --policy flag
	return fmt.Sprintf("%s/%s", ecpNamespace, ecpName), nil
}
