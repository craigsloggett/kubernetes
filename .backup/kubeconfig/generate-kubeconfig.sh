#!/usr/bin/env bash

# Configuration Parameters

node_hostnames=("node-0" "node-1" "node-2")
cluster_name="kubernetes-pi"
controller_ip="192.168.1.110"
KUBERNETES_PUBLIC_ADDRESS="192.168.1.110"

# ---

# The kubelet Kubernetes Configuration File

for node_hostname in "${node_hostnames[@]}"; do
  kubectl config set-cluster ${cluster_name} \
    --certificate-authority=../certs/ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=${node_hostname}.kubeconfig

  kubectl config set-credentials system:node:${node_hostname} \
    --client-certificate=../certs/${node_hostname}.pem \
    --client-key=../certs/${node_hostname}-key.pem \
    --embed-certs=true \
    --kubeconfig=${node_hostname}.kubeconfig

  kubectl config set-context default \
    --cluster=${cluster_name} \
    --user=system:node:${node_hostname} \
    --kubeconfig=${node_hostname}.kubeconfig

  kubectl config use-context default --kubeconfig=${node_hostname}.kubeconfig
done

# ---

# The kube-proxy Kubernetes Configuration File

kubectl config set-cluster ${cluster_name} \
  --certificate-authority=../certs/ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=../certs/kube-proxy.pem \
  --client-key=../certs/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=${cluster_name} \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

# ---

# The kube-controller-manager Kubernetes Configuration File

kubectl config set-cluster ${cluster_name} \
  --certificate-authority=../certs/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=../certs/kube-controller-manager.pem \
  --client-key=../certs/kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=${cluster_name} \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

# ---

# The kube-scheduler Kubernetes Configuration File

kubectl config set-cluster ${cluster_name} \
  --certificate-authority=../certs/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=../certs/kube-scheduler.pem \
  --client-key=../certs/kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=${cluster_name} \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

# ---

# The admin Kubernetes Configuration File

kubectl config set-cluster ${cluster_name} \
  --certificate-authority=../certs/ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=../certs/admin.pem \
  --client-key=../certs/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=${cluster_name} \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig

