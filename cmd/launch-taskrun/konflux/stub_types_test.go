package konflux

import (
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

func TestSnapshot_DeepCopyObject(t *testing.T) {
	original := &Snapshot{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "test-snapshot",
			Namespace: "test-ns",
		},
		Spec: json.RawMessage(`{"application":"test-app"}`),
	}

	copied := original.DeepCopyObject()

	assert.NotSame(t, original, copied)
	assert.Equal(t, original, copied)

	// Verify nil handling
	var nilSnapshot *Snapshot
	assert.Nil(t, nilSnapshot.DeepCopyObject())
}

func TestReleasePlan_DeepCopyObject(t *testing.T) {
	original := &ReleasePlan{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "test-rp",
			Namespace: "test-ns",
		},
		Spec: ReleasePlanSpec{
			Application: "test-app",
			Target:      "test-target",
		},
	}

	copied := original.DeepCopyObject()

	assert.NotSame(t, original, copied)
	assert.Equal(t, original, copied)

	// Verify nil handling
	var nilRP *ReleasePlan
	assert.Nil(t, nilRP.DeepCopyObject())
}

func TestReleasePlanList_DeepCopyObject(t *testing.T) {
	original := &ReleasePlanList{
		Items: []ReleasePlan{
			{
				ObjectMeta: metav1.ObjectMeta{Name: "rp1"},
				Spec:       ReleasePlanSpec{Application: "app1"},
			},
		},
	}

	copied := original.DeepCopyObject()

	assert.NotSame(t, original, copied)
	assert.Equal(t, original, copied)

	// Verify nil handling
	var nilRPL *ReleasePlanList
	assert.Nil(t, nilRPL.DeepCopyObject())
}

func TestReleasePlanAdmission_DeepCopyObject(t *testing.T) {
	original := &ReleasePlanAdmission{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "test-rpa",
			Namespace: "test-ns",
		},
		Spec: ReleasePlanAdmissionSpec{
			Policy: "test-policy",
		},
	}

	copied := original.DeepCopyObject()

	assert.NotSame(t, original, copied)
	assert.Equal(t, original, copied)

	// Verify nil handling
	var nilRPA *ReleasePlanAdmission
	assert.Nil(t, nilRPA.DeepCopyObject())
}

func TestAddToScheme(t *testing.T) {
	scheme := runtime.NewScheme()

	err := AddToScheme(scheme)
	assert.NoError(t, err)

	// Verify types are registered
	gvks, _, _ := scheme.ObjectKinds(&Snapshot{})
	assert.Len(t, gvks, 1)
	assert.Equal(t, "appstudio.redhat.com", gvks[0].Group)
	assert.Equal(t, "v1alpha1", gvks[0].Version)
}
