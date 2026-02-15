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

package controller

import (
	"context"
	"fmt"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	networkingv1 "k8s.io/api/networking/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/util/intstr"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	logf "sigs.k8s.io/controller-runtime/pkg/log"

	appsv1alpha1 "github.com/cncamp/101/Allen/k8slearn/operator/k8s-test-operator/api/v1alpha1"
)

// K8sTestReconciler reconciles a K8sTest object
type K8sTestReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=apps.cncamp.io,resources=k8stests,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=apps.cncamp.io,resources=k8stests/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=apps.cncamp.io,resources=k8stests/finalizers,verbs=update
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=configmaps,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=services,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=networking.k8s.io,resources=ingresses,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=events.k8s.io,resources=events,verbs=create;patch

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// TODO(user): Modify the Reconcile function to compare the state specified by
// the K8sTest object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.23.1/pkg/reconcile
func (r *K8sTestReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := logf.FromContext(ctx)

	var k8stest appsv1alpha1.K8sTest
	if err := r.Get(ctx, req.NamespacedName, &k8stest); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	targetNS := k8stest.Spec.Namespace
	if targetNS == "" {
		targetNS = req.Namespace
	}
	if targetNS != req.Namespace {
		log.Info("spec.namespace must equal CR namespace for this MVP", "crNamespace", req.Namespace, "specNamespace", targetNS)
		return ctrl.Result{}, fmt.Errorf("spec.namespace must equal CR namespace for this MVP (cr=%s spec=%s)", req.Namespace, targetNS)
	}

	imageRegistry := k8stest.Spec.ImageRegistry
	if imageRegistry == "" {
		imageRegistry = "crpi-j9gshcbjtb1i6c7h.cn-hangzhou.personal.cr.aliyuncs.com/tutengdihuang"
	}
	imageTag := k8stest.Spec.ImageTag
	if imageTag == "" {
		imageTag = "latest"
	}
	var replicas int32 = 2
	if k8stest.Spec.Replicas != nil {
		replicas = *k8stest.Spec.Replicas
	}
	pullSecret := k8stest.Spec.PullSecret

	if err := r.ensureEtcdConfigMap(ctx, &k8stest, targetNS); err != nil {
		return ctrl.Result{}, err
	}
	if err := r.ensureServiceConfigMaps(ctx, &k8stest, targetNS); err != nil {
		return ctrl.Result{}, err
	}
	if err := r.ensureEtcd(ctx, &k8stest, targetNS, pullSecret); err != nil {
		return ctrl.Result{}, err
	}
	if err := r.ensureRPCService(ctx, &k8stest, targetNS, "user-service", "user", "user-service-config", imageRegistry+"/user-service:"+imageTag, 9001, replicas, pullSecret); err != nil {
		return ctrl.Result{}, err
	}
	if err := r.ensureRPCService(ctx, &k8stest, targetNS, "product-service", "product", "product-service-config", imageRegistry+"/product-service:"+imageTag, 9002, replicas, pullSecret); err != nil {
		return ctrl.Result{}, err
	}
	if err := r.ensureRPCService(ctx, &k8stest, targetNS, "trade-service", "trade", "trade-service-config", imageRegistry+"/trade-service:"+imageTag, 9003, replicas, pullSecret); err != nil {
		return ctrl.Result{}, err
	}
	if err := r.ensureWeb(ctx, &k8stest, targetNS, imageRegistry+"/web-service:"+imageTag, replicas, pullSecret); err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

func (r *K8sTestReconciler) ensureEtcdConfigMap(ctx context.Context, owner *appsv1alpha1.K8sTest, ns string) error {
	name := "etcd-config"
	var cm corev1.ConfigMap
	cm.Name = name
	cm.Namespace = ns
	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, &cm, func() error {
		if err := controllerutil.SetControllerReference(owner, &cm, r.Scheme); err != nil {
			return err
		}
		if cm.Data == nil {
			cm.Data = map[string]string{}
		}
		cm.Data["etcd-endpoints"] = "etcd-service:2379"
		cm.Data["etcd-key-prefix"] = "/" + ns
		return nil
	})
	return err
}

func (r *K8sTestReconciler) ensureServiceConfigMaps(ctx context.Context, owner *appsv1alpha1.K8sTest, ns string) error {
	configs := map[string]map[string]string{
		"user-service-config":    {"user.yaml": defaultUserConfigYAML},
		"product-service-config": {"product.yaml": defaultProductConfigYAML},
		"trade-service-config":   {"trade.yaml": defaultTradeConfigYAML},
		"web-service-config":     {"web.yaml": defaultWebConfigYAML},
	}
	for name, data := range configs {
		cm := &corev1.ConfigMap{ObjectMeta: metav1.ObjectMeta{Name: name, Namespace: ns}}
		_, err := controllerutil.CreateOrUpdate(ctx, r.Client, cm, func() error {
			if err := controllerutil.SetControllerReference(owner, cm, r.Scheme); err != nil {
				return err
			}
			cm.Data = data
			return nil
		})
		if err != nil {
			return err
		}
	}
	return nil
}

func (r *K8sTestReconciler) ensureEtcd(ctx context.Context, owner *appsv1alpha1.K8sTest, ns string, pullSecret string) error {
	dep := &appsv1.Deployment{ObjectMeta: metav1.ObjectMeta{Name: "etcd", Namespace: ns}}
	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, dep, func() error {
		if err := controllerutil.SetControllerReference(owner, dep, r.Scheme); err != nil {
			return err
		}
		labels := map[string]string{"app": "etcd"}
		dep.Labels = labels
		dep.Spec.Replicas = int32Ptr(1)
		dep.Spec.Selector = &metav1.LabelSelector{MatchLabels: labels}
		dep.Spec.Template.ObjectMeta.Labels = labels
		if pullSecret != "" {
			dep.Spec.Template.Spec.ImagePullSecrets = []corev1.LocalObjectReference{{Name: pullSecret}}
		}
		dep.Spec.Template.Spec.Containers = []corev1.Container{
			{
				Name:  "etcd",
				Image: "registry.aliyuncs.com/google_containers/etcd:3.5.9-0",
				Command: []string{
					"etcd",
					"--listen-client-urls=http://0.0.0.0:2379",
					"--advertise-client-urls=http://0.0.0.0:2379",
				},
				Ports: []corev1.ContainerPort{{ContainerPort: 2379, Name: "client"}},
				Resources: corev1.ResourceRequirements{
					Requests: corev1.ResourceList{"cpu": resource.MustParse("100m"), "memory": resource.MustParse("128Mi")},
					Limits:   corev1.ResourceList{"cpu": resource.MustParse("500m"), "memory": resource.MustParse("256Mi")},
				},
				LivenessProbe:  tcpProbe(2379, 15, 10, 0, 0),
				ReadinessProbe: tcpProbe(2379, 5, 5, 0, 0),
			},
		}
		return nil
	})
	if err != nil {
		return err
	}

	svc := &corev1.Service{ObjectMeta: metav1.ObjectMeta{Name: "etcd-service", Namespace: ns}}
	_, err = controllerutil.CreateOrUpdate(ctx, r.Client, svc, func() error {
		if err := controllerutil.SetControllerReference(owner, svc, r.Scheme); err != nil {
			return err
		}
		labels := map[string]string{"app": "etcd"}
		svc.Labels = labels
		svc.Spec.Type = corev1.ServiceTypeClusterIP
		svc.Spec.Selector = labels
		svc.Spec.Ports = []corev1.ServicePort{{Port: 2379, TargetPort: intstr.FromInt(2379), Protocol: corev1.ProtocolTCP, Name: "client"}}
		return nil
	})
	return err
}

func (r *K8sTestReconciler) ensureRPCService(ctx context.Context, owner *appsv1alpha1.K8sTest, ns, name, containerName, configMapName, image string, port int32, replicas int32, pullSecret string) error {
	dep := &appsv1.Deployment{ObjectMeta: metav1.ObjectMeta{Name: name, Namespace: ns}}
	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, dep, func() error {
		if err := controllerutil.SetControllerReference(owner, dep, r.Scheme); err != nil {
			return err
		}
		labels := map[string]string{"app": name, "version": "v1"}
		dep.Labels = labels
		dep.Spec.Replicas = int32Ptr(replicas)
		dep.Spec.Selector = &metav1.LabelSelector{MatchLabels: map[string]string{"app": name}}
		dep.Spec.Template.ObjectMeta.Labels = labels
		if pullSecret != "" {
			dep.Spec.Template.Spec.ImagePullSecrets = []corev1.LocalObjectReference{{Name: pullSecret}}
		}
		dep.Spec.Template.Spec.Containers = []corev1.Container{
			{
				Name:            containerName,
				Image:           image,
				ImagePullPolicy: corev1.PullAlways,
				Ports:           []corev1.ContainerPort{{ContainerPort: port, Name: "grpc", Protocol: corev1.ProtocolTCP}},
				VolumeMounts:    []corev1.VolumeMount{{Name: "config", MountPath: "/app/etc", ReadOnly: true}},
				Resources: corev1.ResourceRequirements{
					Requests: corev1.ResourceList{"cpu": resource.MustParse("100m"), "memory": resource.MustParse("128Mi")},
					Limits:   corev1.ResourceList{"cpu": resource.MustParse("500m"), "memory": resource.MustParse("256Mi")},
				},
				LivenessProbe:  tcpProbe(int(port), 30, 10, 5, 3),
				ReadinessProbe: tcpProbe(int(port), 10, 5, 3, 3),
			},
		}
		dep.Spec.Template.Spec.Volumes = []corev1.Volume{
			{Name: "config", VolumeSource: corev1.VolumeSource{ConfigMap: &corev1.ConfigMapVolumeSource{LocalObjectReference: corev1.LocalObjectReference{Name: configMapName}}}},
		}
		return nil
	})
	if err != nil {
		return err
	}

	svc := &corev1.Service{ObjectMeta: metav1.ObjectMeta{Name: name, Namespace: ns}}
	_, err = controllerutil.CreateOrUpdate(ctx, r.Client, svc, func() error {
		if err := controllerutil.SetControllerReference(owner, svc, r.Scheme); err != nil {
			return err
		}
		labels := map[string]string{"app": name}
		svc.Labels = labels
		svc.Spec.Type = corev1.ServiceTypeClusterIP
		svc.Spec.Selector = labels
		svc.Spec.Ports = []corev1.ServicePort{{Port: port, TargetPort: intstr.FromInt(int(port)), Protocol: corev1.ProtocolTCP, Name: "grpc"}}
		return nil
	})
	return err
}

func (r *K8sTestReconciler) ensureWeb(ctx context.Context, owner *appsv1alpha1.K8sTest, ns, image string, replicas int32, pullSecret string) error {
	name := "web-service"
	dep := &appsv1.Deployment{ObjectMeta: metav1.ObjectMeta{Name: name, Namespace: ns}}
	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, dep, func() error {
		if err := controllerutil.SetControllerReference(owner, dep, r.Scheme); err != nil {
			return err
		}
		labels := map[string]string{"app": name, "version": "v1"}
		dep.Labels = labels
		dep.Spec.Replicas = int32Ptr(replicas)
		dep.Spec.Selector = &metav1.LabelSelector{MatchLabels: map[string]string{"app": name}}
		dep.Spec.Template.ObjectMeta.Labels = labels
		if pullSecret != "" {
			dep.Spec.Template.Spec.ImagePullSecrets = []corev1.LocalObjectReference{{Name: pullSecret}}
		}
		dep.Spec.Template.Spec.Containers = []corev1.Container{
			{
				Name:            "web",
				Image:           image,
				ImagePullPolicy: corev1.PullAlways,
				Ports:           []corev1.ContainerPort{{ContainerPort: 8888, Name: "http", Protocol: corev1.ProtocolTCP}},
				VolumeMounts:    []corev1.VolumeMount{{Name: "config", MountPath: "/app/etc", ReadOnly: true}},
				Resources: corev1.ResourceRequirements{
					Requests: corev1.ResourceList{"cpu": resource.MustParse("100m"), "memory": resource.MustParse("128Mi")},
					Limits:   corev1.ResourceList{"cpu": resource.MustParse("500m"), "memory": resource.MustParse("256Mi")},
				},
				LivenessProbe:  tcpProbe(8888, 30, 10, 5, 3),
				ReadinessProbe: tcpProbe(8888, 10, 5, 3, 3),
			},
		}
		dep.Spec.Template.Spec.Volumes = []corev1.Volume{
			{Name: "config", VolumeSource: corev1.VolumeSource{ConfigMap: &corev1.ConfigMapVolumeSource{LocalObjectReference: corev1.LocalObjectReference{Name: "web-service-config"}}}},
		}
		return nil
	})
	if err != nil {
		return err
	}

	svc := &corev1.Service{ObjectMeta: metav1.ObjectMeta{Name: name, Namespace: ns}}
	_, err = controllerutil.CreateOrUpdate(ctx, r.Client, svc, func() error {
		if err := controllerutil.SetControllerReference(owner, svc, r.Scheme); err != nil {
			return err
		}
		labels := map[string]string{"app": name}
		svc.Labels = labels
		svc.Spec.Type = corev1.ServiceTypeNodePort
		svc.Spec.Selector = labels
		svc.Spec.Ports = []corev1.ServicePort{{Port: 8888, TargetPort: intstr.FromInt(8888), Protocol: corev1.ProtocolTCP, Name: "http", NodePort: 30888}}
		return nil
	})
	if err != nil {
		return err
	}

	pathType := networkingv1.PathTypePrefix
	ing := &networkingv1.Ingress{ObjectMeta: metav1.ObjectMeta{Name: "web-ingress", Namespace: ns}}
	_, err = controllerutil.CreateOrUpdate(ctx, r.Client, ing, func() error {
		if err := controllerutil.SetControllerReference(owner, ing, r.Scheme); err != nil {
			return err
		}
		if ing.Annotations == nil {
			ing.Annotations = map[string]string{}
		}
		ing.Annotations["kubernetes.io/ingress.class"] = "nginx"
		ing.Spec.Rules = []networkingv1.IngressRule{
			{
				Host: "service-test.example.com",
				IngressRuleValue: networkingv1.IngressRuleValue{HTTP: &networkingv1.HTTPIngressRuleValue{Paths: []networkingv1.HTTPIngressPath{
					{
						Path:     "/",
						PathType: &pathType,
						Backend:  networkingv1.IngressBackend{Service: &networkingv1.IngressServiceBackend{Name: name, Port: networkingv1.ServiceBackendPort{Number: 8888}}},
					},
				}}},
			},
		}
		return nil
	})
	return err
}

func int32Ptr(v int32) *int32 { return &v }

func tcpProbe(port int, initialDelaySeconds, periodSeconds, timeoutSeconds, failureThreshold int32) *corev1.Probe {
	p := &corev1.Probe{ProbeHandler: corev1.ProbeHandler{TCPSocket: &corev1.TCPSocketAction{Port: intstr.FromInt(port)}}}
	if initialDelaySeconds != 0 {
		p.InitialDelaySeconds = initialDelaySeconds
	}
	if periodSeconds != 0 {
		p.PeriodSeconds = periodSeconds
	}
	if timeoutSeconds != 0 {
		p.TimeoutSeconds = timeoutSeconds
	}
	if failureThreshold != 0 {
		p.FailureThreshold = failureThreshold
	}
	return p
}

const defaultUserConfigYAML = "Name: user.rpc\nListenOn: 0.0.0.0:9001\nEtcd:\n  Hosts:\n    - etcd-service:2379\n  Key: user.rpc\nTradeRpc:\n  Etcd:\n    Hosts:\n      - etcd-service:2379\n    Key: trade.rpc\n  NonBlock: true\n  Timeout: 5000\n"

const defaultProductConfigYAML = "Name: product.rpc\nListenOn: 0.0.0.0:9002\nEtcd:\n  Hosts:\n    - etcd-service:2379\n  Key: product.rpc\n"

const defaultTradeConfigYAML = "Name: trade.rpc\nListenOn: 0.0.0.0:9003\nEtcd:\n  Hosts:\n    - etcd-service:2379\n  Key: trade.rpc\nUserRpc:\n  Etcd:\n    Hosts:\n      - etcd-service:2379\n    Key: user.rpc\n  NonBlock: true\n  Timeout: 5000\nProductRpc:\n  Etcd:\n    Hosts:\n      - etcd-service:2379\n    Key: product.rpc\n  NonBlock: true\n  Timeout: 5000\n"

const defaultWebConfigYAML = "Name: web-api\nHost: 0.0.0.0\nPort: 8888\nUserRpc:\n  Etcd:\n    Hosts:\n      - etcd-service:2379\n    Key: user.rpc\n  NonBlock: true\n  Timeout: 5000\nProductRpc:\n  Etcd:\n    Hosts:\n      - etcd-service:2379\n    Key: product.rpc\n  NonBlock: true\n  Timeout: 5000\nTradeRpc:\n  Etcd:\n    Hosts:\n      - etcd-service:2379\n    Key: trade.rpc\n  NonBlock: true\n  Timeout: 5000\n"

// SetupWithManager sets up the controller with the Manager.
func (r *K8sTestReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&appsv1alpha1.K8sTest{}).
		Named("k8stest").
		Complete(r)
}
