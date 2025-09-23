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
	"fmt"

	gozap "go.uber.org/zap"
	corev1 "k8s.io/api/core/v1"
	"sigs.k8s.io/controller-runtime/pkg/client"
)

// Struct for specifying one particular value from a secret
type SecretValueKey struct {
	client.ObjectKey
	SecretKey string
}

// Helper to create an instance of the SecretValueKey struct defined above
func NewSecretValueKey(namespace, name, secretKey string) SecretValueKey {
	return SecretValueKey{
		ObjectKey: client.ObjectKey{Namespace: namespace, Name: name},
		SecretKey: secretKey,
	}
}

// FindPublicKey retrieves the cosign public key from the cluster secret
// See also https://konflux.pages.redhat.com/docs/users/public-keys.html
func FindPublicKey(ctx context.Context, cli ClientReader, logger Logger, svk SecretValueKey) (string, error) {
	// Get the secret
	var secret corev1.Secret
	err := cli.Get(ctx, svk.ObjectKey, &secret)
	if err != nil {
		return "", fmt.Errorf("failed to get secret %s/%s: %w", svk.Namespace, svk.Name, err)
	}

	// Extract cosign.pub data (which comes already base64 decoded)
	cosignPubData, exists := secret.Data[svk.SecretKey]
	if !exists {
		return "", fmt.Errorf("%s not found in secret %s/%s", svk.SecretKey, svk.Namespace, svk.Name)
	}

	logger.Info("Found public key", gozap.String("namespace", svk.Namespace), gozap.String("secret", svk.Name))
	return string(cosignPubData), nil
}
