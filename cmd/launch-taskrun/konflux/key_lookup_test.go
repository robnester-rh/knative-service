// Copyright The Conforma Contributors
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0

package konflux

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"sigs.k8s.io/controller-runtime/pkg/client/fake"
)

func TestFindPublicKey_Success(t *testing.T) {
	scheme := runtime.NewScheme()
	require.NoError(t, corev1.AddToScheme(scheme))

	// Test data - the actual public key that should be returned
	expectedKey := `-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEZP/0htjhVt2y0ohjgtIIgICOtQtA
naYJRuLprwIv6FDhZ5yFjYUEtsmoNcW7rx2KM6FOXGsCX3BNc7qhHELT+g==
-----END PUBLIC KEY-----`

	// Test configuration
	secretNs := "test-namespace"
	secretName := "test-secret"
	secretKey := "test-key"

	// Create test secret with the key data directly (K8s automatically handles base64 encoding/decoding)
	secret := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Name:      secretName,
			Namespace: secretNs,
		},
		Data: map[string][]byte{
			secretKey: []byte(expectedKey),
		},
	}

	// Create fake client with test secret
	cli := fake.NewClientBuilder().
		WithScheme(scheme).
		WithObjects(secret).
		Build()

	logger := &mockLogger{t: t}

	// Test successful key lookup
	result, err := FindPublicKey(context.Background(), cli, logger, secretNs, secretName, secretKey)

	assert.NoError(t, err)
	assert.Equal(t, expectedKey, result)
}

func TestFindPublicKey_SecretNotFound(t *testing.T) {
	scheme := runtime.NewScheme()
	require.NoError(t, corev1.AddToScheme(scheme))

	// Create fake client without the secret
	cli := fake.NewClientBuilder().
		WithScheme(scheme).
		Build()

	logger := &mockLogger{t: t}

	// Test configuration
	secretNs := "test-namespace"
	secretName := "test-secret"
	secretKey := "test-key"

	// Test secret not found error
	result, err := FindPublicKey(context.Background(), cli, logger, secretNs, secretName, secretKey)

	assert.Error(t, err)
	assert.Empty(t, result)
	assert.Contains(t, err.Error(), "failed to get secret test-namespace/test-secret")
}

func TestFindPublicKey_KeyNotFoundInSecret(t *testing.T) {
	scheme := runtime.NewScheme()
	require.NoError(t, corev1.AddToScheme(scheme))

	// Test configuration
	secretNs := "test-namespace"
	secretName := "test-secret"
	secretKey := "test-key"

	// Create secret without the expected key
	secret := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Name:      secretName,
			Namespace: secretNs,
		},
		Data: map[string][]byte{
			"other-key": []byte("other-value"),
		},
	}

	cli := fake.NewClientBuilder().
		WithScheme(scheme).
		WithObjects(secret).
		Build()

	logger := &mockLogger{t: t}

	// Test key not found in secret
	result, err := FindPublicKey(context.Background(), cli, logger, secretNs, secretName, secretKey)

	assert.Error(t, err)
	assert.Empty(t, result)
	assert.Contains(t, err.Error(), "test-key not found in secret test-namespace/test-secret")
}

func TestFindPublicKey_WithSpecialCharacters(t *testing.T) {
	scheme := runtime.NewScheme()
	require.NoError(t, corev1.AddToScheme(scheme))

	// Test configuration
	secretNs := "test-namespace"
	secretName := "test-secret"
	secretKey := "test-key"

	// Create secret with data containing special characters
	testKey := "special-key-data!@#$%"
	secret := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Name:      secretName,
			Namespace: secretNs,
		},
		Data: map[string][]byte{
			secretKey: []byte(testKey),
		},
	}

	cli := fake.NewClientBuilder().
		WithScheme(scheme).
		WithObjects(secret).
		Build()

	logger := &mockLogger{t: t}

	// Test that special characters are handled correctly
	result, err := FindPublicKey(context.Background(), cli, logger, secretNs, secretName, secretKey)

	assert.NoError(t, err)
	assert.Equal(t, testKey, result)
}

func TestFindPublicKey_EmptySecret(t *testing.T) {
	scheme := runtime.NewScheme()
	require.NoError(t, corev1.AddToScheme(scheme))

	// Test configuration
	secretNs := "test-namespace"
	secretName := "test-secret"
	secretKey := "test-key"

	// Create secret with empty data
	secret := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Name:      secretName,
			Namespace: secretNs,
		},
		Data: map[string][]byte{},
	}

	cli := fake.NewClientBuilder().
		WithScheme(scheme).
		WithObjects(secret).
		Build()

	logger := &mockLogger{t: t}

	// Test empty secret
	result, err := FindPublicKey(context.Background(), cli, logger, secretNs, secretName, secretKey)

	assert.Error(t, err)
	assert.Empty(t, result)
	assert.Contains(t, err.Error(), "test-key not found in secret test-namespace/test-secret")
}

func TestFindPublicKey_EmptyKeyValue(t *testing.T) {
	scheme := runtime.NewScheme()
	require.NoError(t, corev1.AddToScheme(scheme))

	// Test configuration
	secretNs := "test-namespace"
	secretName := "test-secret"
	secretKey := "test-key"

	// Create secret with empty key value
	secret := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Name:      secretName,
			Namespace: secretNs,
		},
		Data: map[string][]byte{
			secretKey: []byte(""), // Empty string
		},
	}

	cli := fake.NewClientBuilder().
		WithScheme(scheme).
		WithObjects(secret).
		Build()

	logger := &mockLogger{t: t}

	// Test empty key value - should succeed but return empty string
	result, err := FindPublicKey(context.Background(), cli, logger, secretNs, secretName, secretKey)

	assert.NoError(t, err)
	assert.Equal(t, "", result)
}

func TestFindPublicKey_DifferentNamespace(t *testing.T) {
	scheme := runtime.NewScheme()
	require.NoError(t, corev1.AddToScheme(scheme))

	// Test configuration
	secretNs := "expected-namespace"
	secretName := "test-secret"
	secretKey := "test-key"

	// Create secret in different namespace
	secret := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Name:      secretName,
			Namespace: "different-namespace",
		},
		Data: map[string][]byte{
			secretKey: []byte("test-key"),
		},
	}

	cli := fake.NewClientBuilder().
		WithScheme(scheme).
		WithObjects(secret).
		Build()

	logger := &mockLogger{t: t}

	// Test that function looks in correct namespace (should not find the secret)
	result, err := FindPublicKey(context.Background(), cli, logger, secretNs, secretName, secretKey)

	assert.Error(t, err)
	assert.Empty(t, result)
	assert.Contains(t, err.Error(), "failed to get secret expected-namespace/test-secret")
}
