package controllers

import (
	"context"

	corev1 "k8s.io/api/core/v1"
	rbacv1 "k8s.io/api/rbac/v1"
	apierrors "k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"

	tenantv1alpha1 "github.com/cncamp/101/Allen/k8slearn/operator/tenant-operator/pkg/apis/tenant/v1alpha1"
)

const tenantFinalizer = "tenant.cncamp.io/finalizer"

type TenantReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

func (r *TenantReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	var tenant tenantv1alpha1.Tenant
	if err := r.Get(ctx, req.NamespacedName, &tenant); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	nsName := tenant.Spec.Namespace
	if nsName == "" {
		nsName = tenant.Name
	}

	if tenant.DeletionTimestamp != nil {
		if controllerutil.ContainsFinalizer(&tenant, tenantFinalizer) {
			controllerutil.RemoveFinalizer(&tenant, tenantFinalizer)
			if err := r.Update(ctx, &tenant); err != nil {
				return ctrl.Result{}, err
			}
		}
		return ctrl.Result{}, nil
	}

	if !controllerutil.ContainsFinalizer(&tenant, tenantFinalizer) {
		controllerutil.AddFinalizer(&tenant, tenantFinalizer)
		if err := r.Update(ctx, &tenant); err != nil {
			return ctrl.Result{}, err
		}
	}

	if err := r.ensureNamespace(ctx, &tenant, nsName); err != nil {
		return ctrl.Result{}, err
	}
	if err := r.ensureResourceQuota(ctx, &tenant, nsName); err != nil {
		return ctrl.Result{}, err
	}
	if err := r.ensureRBAC(ctx, &tenant, nsName); err != nil {
		return ctrl.Result{}, err
	}

	tenant.Status.Phase = "Ready"
	tenant.Status.ObservedGeneration = tenant.Generation
	tenant.Status.LastAppliedNamespace = nsName
	if err := r.Status().Update(ctx, &tenant); err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

func (r *TenantReconciler) ensureNamespace(ctx context.Context, tenant *tenantv1alpha1.Tenant, nsName string) error {
	var ns corev1.Namespace
	err := r.Get(ctx, types.NamespacedName{Name: nsName}, &ns)
	if apierrors.IsNotFound(err) {
		ns = corev1.Namespace{}
		ns.Name = nsName
		if err := controllerutil.SetControllerReference(tenant, &ns, r.Scheme); err != nil {
			return err
		}
		return r.Create(ctx, &ns)
	}
	return err
}

func (r *TenantReconciler) ensureResourceQuota(ctx context.Context, tenant *tenantv1alpha1.Tenant, nsName string) error {
	rqName := "object-counts"
	var rq corev1.ResourceQuota
	err := r.Get(ctx, types.NamespacedName{Name: rqName, Namespace: nsName}, &rq)
	if apierrors.IsNotFound(err) {
		rq = corev1.ResourceQuota{}
		rq.Name = rqName
		rq.Namespace = nsName
		if err := controllerutil.SetControllerReference(tenant, &rq, r.Scheme); err != nil {
			return err
		}
	}
	if err != nil && !apierrors.IsNotFound(err) {
		return err
	}

	hard := corev1.ResourceList{}
	oc := tenant.Spec.ObjectCounts
	if oc == nil {
		hard[corev1.ResourceConfigMaps] = resourceQuantity("20")
		hard[corev1.ResourceSecrets] = resourceQuantity("20")
		hard[corev1.ResourceServices] = resourceQuantity("10")
		hard[corev1.ResourceServicesLoadBalancers] = resourceQuantity("20")
		hard[corev1.ResourceServicesNodePorts] = resourceQuantity("30")
	} else {
		if oc.ConfigMaps != "" {
			hard[corev1.ResourceConfigMaps] = resourceQuantity(oc.ConfigMaps)
		}
		if oc.Secrets != "" {
			hard[corev1.ResourceSecrets] = resourceQuantity(oc.Secrets)
		}
		if oc.Services != "" {
			hard[corev1.ResourceServices] = resourceQuantity(oc.Services)
		}
		if oc.LoadBalancers != "" {
			hard[corev1.ResourceServicesLoadBalancers] = resourceQuantity(oc.LoadBalancers)
		}
		if oc.NodePorts != "" {
			hard[corev1.ResourceServicesNodePorts] = resourceQuantity(oc.NodePorts)
		}
	}

	rq.Spec.Hard = hard

	if rq.CreationTimestamp.IsZero() {
		return r.Create(ctx, &rq)
	}
	return r.Update(ctx, &rq)
}

func (r *TenantReconciler) ensureRBAC(ctx context.Context, tenant *tenantv1alpha1.Tenant, nsName string) error {
	user := tenant.Spec.AdminUser
	if user == "" {
		user = "mfanjie"
	}

	crName := "pod-admin"
	var cr rbacv1.ClusterRole
	if err := r.Get(ctx, types.NamespacedName{Name: crName}, &cr); err != nil {
		if !apierrors.IsNotFound(err) {
			return err
		}
		cr = rbacv1.ClusterRole{}
		cr.Name = crName
		cr.Rules = []rbacv1.PolicyRule{
			{
				APIGroups: []string{""},
				Resources: []string{"pods", "pods/attach", "pods/binding", "pods/eviction", "pods/exec", "pods/log", "pods/portforward", "pods/proxy", "pods/status", "pods/ephemeralcontainers"},
				Verbs:     []string{"*"},
			},
		}
		if err := r.Create(ctx, &cr); err != nil {
			return err
		}
	}

	rbName := "pod-admin"
	var rb rbacv1.RoleBinding
	err := r.Get(ctx, types.NamespacedName{Name: rbName, Namespace: nsName}, &rb)
	if apierrors.IsNotFound(err) {
		rb = rbacv1.RoleBinding{}
		rb.Name = rbName
		rb.Namespace = nsName
		if err := controllerutil.SetControllerReference(tenant, &rb, r.Scheme); err != nil {
			return err
		}
	}
	if err != nil && !apierrors.IsNotFound(err) {
		return err
	}

	rb.RoleRef = rbacv1.RoleRef{APIGroup: "rbac.authorization.k8s.io", Kind: "ClusterRole", Name: crName}
	rb.Subjects = []rbacv1.Subject{
		{APIGroup: "rbac.authorization.k8s.io", Kind: "User", Name: user},
		{Kind: "ServiceAccount", Name: "default", Namespace: nsName},
	}

	if rb.CreationTimestamp.IsZero() {
		return r.Create(ctx, &rb)
	}
	return r.Update(ctx, &rb)
}

func (r *TenantReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&tenantv1alpha1.Tenant{}).
		Owns(&corev1.ResourceQuota{}).
		Owns(&rbacv1.RoleBinding{}).
		Complete(r)
}
