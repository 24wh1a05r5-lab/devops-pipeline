#!/usr/bin/env bash
# Zero-cost local demo: kind cluster + Argo CD + monitoring stack. No AWS needed.
set -euo pipefail
kind create cluster --name devops --wait 120s || true
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts && helm repo update
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f monitoring/alertmanager-values.yaml
kubectl apply -f monitoring/prometheus-rules.yaml
kubectl apply -f argocd/project.yaml -f argocd/app-dev.yaml
echo "Argo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
echo "UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
