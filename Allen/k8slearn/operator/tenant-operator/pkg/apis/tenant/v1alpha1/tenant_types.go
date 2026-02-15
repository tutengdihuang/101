package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type TenantSpec struct {
	Namespace string `json:"namespace"`
	ObjectCounts *ObjectCountsQuota `json:"objectCounts,omitempty"`
	PodQuota *PodQuota `json:"podQuota,omitempty"`
	AdminUser string `json:"adminUser,omitempty"`
}

type ObjectCountsQuota struct {
	ConfigMaps string `json:"configMaps,omitempty"`
	Secrets string `json:"secrets,omitempty"`
	Services string `json:"services,omitempty"`
	LoadBalancers string `json:"loadBalancers,omitempty"`
	NodePorts string `json:"nodePorts,omitempty"`
}

type PodQuota struct {
	Pods string `json:"pods,omitempty"`
}

type TenantStatus struct {
	Phase string `json:"phase,omitempty"`
	ObservedGeneration int64 `json:"observedGeneration,omitempty"`
	LastAppliedNamespace string `json:"lastAppliedNamespace,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status

type Tenant struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   TenantSpec   `json:"spec,omitempty"`
	Status TenantStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

type TenantList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Tenant `json:"items"`
}

func init() {
	SchemeBuilder.Register(&Tenant{}, &TenantList{})
}
