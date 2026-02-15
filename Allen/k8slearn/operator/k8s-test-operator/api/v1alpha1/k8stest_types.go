/*
Copyright 2026.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json tags for the fields to be serialized.

// K8sTestSpec defines the desired state of K8sTest
type K8sTestSpec struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "make" to regenerate code after modifying this file
	// The following markers will use OpenAPI v3 schema to validate the value
	// More info: https://book.kubebuilder.io/reference/markers/crd-validation.html

	// foo is an example field of K8sTest. Edit k8stest_types.go to remove/update
	// +optional
	Foo *string `json:"foo,omitempty"`

	Namespace     string `json:"namespace,omitempty"`
	ImageRegistry string `json:"imageRegistry,omitempty"`
	ImageTag      string `json:"imageTag,omitempty"`
	Replicas      *int32 `json:"replicas,omitempty"`
	PullSecret    string `json:"pullSecret,omitempty"`
}

// K8sTestStatus defines the observed state of K8sTest.
type K8sTestStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "make" to regenerate code after modifying this file

	// For Kubernetes API conventions, see:
	// https://github.com/kubernetes/community/blob/master/contributors/devel/sig-architecture/api-conventions.md#typical-status-properties

	// conditions represent the current state of the K8sTest resource.
	// Each condition has a unique type and reflects the status of a specific aspect of the resource.
	//
	// Standard condition types include:
	// - "Available": the resource is fully functional
	// - "Progressing": the resource is being created or updated
	// - "Degraded": the resource failed to reach or maintain its desired state
	//
	// The status of each condition is one of True, False, or Unknown.
	// +listType=map
	// +listMapKey=type
	// +optional
	Conditions []metav1.Condition `json:"conditions,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status

// K8sTest is the Schema for the k8stests API
type K8sTest struct {
	metav1.TypeMeta `json:",inline"`

	// metadata is a standard object metadata
	// +optional
	metav1.ObjectMeta `json:"metadata,omitzero"`

	// spec defines the desired state of K8sTest
	// +required
	Spec K8sTestSpec `json:"spec"`

	// status defines the observed state of K8sTest
	// +optional
	Status K8sTestStatus `json:"status,omitzero"`
}

// +kubebuilder:object:root=true

// K8sTestList contains a list of K8sTest
type K8sTestList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitzero"`
	Items           []K8sTest `json:"items"`
}

func init() {
	SchemeBuilder.Register(&K8sTest{}, &K8sTestList{})
}
