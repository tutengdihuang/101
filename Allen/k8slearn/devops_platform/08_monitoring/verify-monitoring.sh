#!/bin/bash

set -e

MASTER_IP="182.42.82.135"
SSH_USER="root"
SSH_PASS="1Qaz2Wsx"
KUBECONFIG="/etc/kubernetes/admin.conf"
GRAFANA_USER="admin"
GRAFANA_PASS="admin123"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

check_service_monitor() {
    log_info "步骤 1: 验证 ServiceMonitor 存在性"
    
    local result=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no ${SSH_USER}@${MASTER_IP} "KUBECONFIG=$KUBECONFIG kubectl get servicemonitors -n monitoring -o json" 2>/dev/null || echo "ERROR")
    
    if [[ "$result" == "ERROR" ]]; then
        log_error "无法获取 ServiceMonitor 列表"
        ((FAIL_COUNT++))
        return 1
    fi
    
    local tekton_exists=$(echo "$result" | grep -q "tekton-servicemonitor" && echo "true" || echo "false")
    local argocd_exists=$(echo "$result" | grep -q "argocd" && echo "true" || echo "false")
    
    if [[ "$tekton_exists" == "true" ]]; then
        log_info "✓ Tekton ServiceMonitor 存在"
        ((PASS_COUNT++))
    else
        log_error "✗ Tekton ServiceMonitor 不存在"
        ((FAIL_COUNT++))
    fi
    
    if [[ "$argocd_exists" == "true" ]]; then
        log_info "✓ ArgoCD ServiceMonitor 存在"
        ((PASS_COUNT++))
    else
        log_error "✗ ArgoCD ServiceMonitor 不存在"
        ((FAIL_COUNT++))
    fi
    
    echo ""
}

check_prometheus_targets() {
    log_info "步骤 2: 验证 Prometheus Targets 状态"
    
    local prometheus_pod=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no ${SSH_USER}@${MASTER_IP} "KUBECONFIG=$KUBECONFIG kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}'" 2>/dev/null || echo "")
    
    if [[ -z "$prometheus_pod" ]]; then
        log_error "无法找到 Prometheus Pod"
        ((FAIL_COUNT++))
        return 1
    fi
    
    log_info "Prometheus Pod: $prometheus_pod"
    
    local targets=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no ${SSH_USER}@${MASTER_IP} "KUBECONFIG=$KUBECONFIG kubectl exec -n monitoring $prometheus_pod -- wget -qO- http://localhost:9090/api/v1/targets" 2>/dev/null || echo "ERROR")
    
    if [[ "$targets" == "ERROR" ]]; then
        log_error "无法获取 Prometheus Targets"
        ((FAIL_COUNT++))
        return 1
    fi
    
    local tekton_targets=$(echo "$targets" | grep -o '"job":"[^"]*tekton[^"]*"' | wc -l)
    local argocd_targets=$(echo "$targets" | grep -o '"job":"[^"]*argocd[^"]*"' | wc -l)
    
    if [[ $tekton_targets -gt 0 ]]; then
        log_info "✓ 找到 $tekton_targets 个 Tekton 相关的 Target"
        ((PASS_COUNT++))
    else
        log_error "✗ 未找到 Tekton 相关的 Target"
        ((FAIL_COUNT++))
    fi
    
    if [[ $argocd_targets -gt 0 ]]; then
        log_info "✓ 找到 $argocd_targets 个 ArgoCD 相关的 Target"
        ((PASS_COUNT++))
    else
        log_error "✗ 未找到 ArgoCD 相关的 Target"
        ((FAIL_COUNT++))
    fi
    
    echo ""
}

check_tekton_metrics() {
    log_info "步骤 3: 验证 Tekton 指标数据"
    
    local prometheus_pod=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no ${SSH_USER}@${MASTER_IP} "KUBECONFIG=$KUBECONFIG kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}'" 2>/dev/null || echo "")
    
    if [[ -z "$prometheus_pod" ]]; then
        log_error "无法找到 Prometheus Pod"
        ((FAIL_COUNT++))
        return 1
    fi
    
    local metrics=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no ${SSH_USER}@${MASTER_IP} "KUBECONFIG=$KUBECONFIG kubectl exec -n monitoring $prometheus_pod -- wget -qO- 'http://localhost:9090/api/v1/query?query=up{job=~\".*tekton.*\"}'" 2>/dev/null || echo "ERROR")
    
    if [[ "$metrics" == "ERROR" ]]; then
        log_error "无法查询 Tekton 指标"
        ((FAIL_COUNT++))
        return 1
    fi
    
    local data_points=$(echo "$metrics" | grep -o '"result":\[' | wc -l)
    
    if [[ $data_points -gt 0 ]]; then
        log_info "✓ Tekton 指标数据存在"
        ((PASS_COUNT++))
    else
        log_error "✗ Tekton 指标数据不存在"
        ((FAIL_COUNT++))
    fi
    
    echo ""
}

check_argocd_metrics() {
    log_info "步骤 4: 验证 ArgoCD 指标数据"
    
    local prometheus_pod=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no ${SSH_USER}@${MASTER_IP} "KUBECONFIG=$KUBECONFIG kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}'" 2>/dev/null || echo "")
    
    if [[ -z "$prometheus_pod" ]]; then
        log_error "无法找到 Prometheus Pod"
        ((FAIL_COUNT++))
        return 1
    fi
    
    local metrics=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no ${SSH_USER}@${MASTER_IP} "KUBECONFIG=$KUBECONFIG kubectl exec -n monitoring $prometheus_pod -- wget -qO- 'http://localhost:9090/api/v1/query?query=up{job=~\".*argocd.*\"}'" 2>/dev/null || echo "ERROR")
    
    if [[ "$metrics" == "ERROR" ]]; then
        log_error "无法查询 ArgoCD 指标"
        ((FAIL_COUNT++))
        return 1
    fi
    
    local data_points=$(echo "$metrics" | grep -o '"result":\[' | wc -l)
    
    if [[ $data_points -gt 0 ]]; then
        log_info "✓ ArgoCD 指标数据存在"
        ((PASS_COUNT++))
    else
        log_error "✗ ArgoCD 指标数据不存在"
        ((FAIL_COUNT++))
    fi
    
    echo ""
}

check_grafana_dashboard() {
    log_info "步骤 5: 验证 Grafana Dashboard"
    
    local dashboards=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no ${SSH_USER}@${MASTER_IP} "curl -s http://${GRAFANA_USER}:${GRAFANA_PASS}@localhost:30300/api/search?query=DevOps" 2>/dev/null || echo "ERROR")
    
    if [[ "$dashboards" == "ERROR" ]]; then
        log_error "无法连接到 Grafana API"
        ((FAIL_COUNT++))
        return 1
    fi
    
    local devops_dashboard=$(echo "$dashboards" | grep -q "DevOps Platform Overview" && echo "true" || echo "false")
    
    if [[ "$devops_dashboard" == "true" ]]; then
        log_info "✓ DevOps Platform Overview Dashboard 存在"
        ((PASS_COUNT++))
    else
        log_error "✗ DevOps Platform Overview Dashboard 不存在"
        ((FAIL_COUNT++))
    fi
    
    echo ""
}

generate_report() {
    log_info "========================================="
    log_info "验证报告"
    log_info "========================================="
    echo ""
    log_info "通过: $PASS_COUNT"
    log_info "失败: $FAIL_COUNT"
    echo ""
    
    if [[ $FAIL_COUNT -eq 0 ]]; then
        log_info "✓ 所有验证通过！"
        return 0
    else
        log_error "✗ 有 $FAIL_COUNT 个验证失败"
        return 1
    fi
}

main() {
    echo ""
    log_info "========================================="
    log_info "监控系统一键验证脚本"
    log_info "========================================="
    echo ""
    
    check_service_monitor
    check_prometheus_targets
    check_tekton_metrics
    check_argocd_metrics
    check_grafana_dashboard
    
    generate_report
}

main "$@"
