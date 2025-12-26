#!/bin/bash

set -e

echo "Updating kubeconfig..."
aws eks --region us-east-1 update-kubeconfig --name amazon-prime-cluster

echo "------------------------"

# ArgoCD
ARGO_URL=$(kubectl get svc argocd-server -n argocd \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode)

# Prometheus
PROM_URL=$(kubectl get svc monitoring-kube-prometheus-prometheus -n prometheus \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Grafana
GRAFANA_URL=$(kubectl get svc monitoring-grafana -n prometheus \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

GRAFANA_PWD=$(kubectl get secret monitoring-grafana -n prometheus \
  -o jsonpath="{.data.admin-password}" | base64 --decode)

echo "ArgoCD URL: http://$ARGO_URL"
echo "ArgoCD User: admin"
echo "ArgoCD Initial Password: $ARGO_PWD"
echo
echo "Prometheus URL: http://$PROM_URL:9090"
echo
echo "Grafana URL: http://$GRAFANA_URL"
echo "Grafana User: admin"
echo "Grafana Password: $GRAFANA_PWD"
echo "------------------------"
