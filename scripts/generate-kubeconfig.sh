#!/usr/bin/env bash

# Configuration Parameters

node_hostnames=("node-0" "node-1" "node-2")
cluster_name="kubernetes"
public_ip="192.168.1.110"

# Verify the certificates have been created.
[ -d "../certs" ] || exit

# Create a place to store the configuration files.
[ ! -d "../kubeconfig" ] && mkdir "../kubeconfig"
cd "../kubeconfig" || exit

# ---

# The kubelet Kubernetes Configuration File

for node_hostname in "${node_hostnames[@]}"; do
  kubectl config set-cluster ${cluster_name} \
    --certificate-authority=../certs/ca.pem \
    --embed-certs=true \
    --server=https://${public_ip}:6443 \
    --kubeconfig=${node_hostname}.conf

  kubectl config set-credentials system:node:${node_hostname} \
    --client-certificate=../certs/${node_hostname}.pem \
    --client-key=../certs/${node_hostname}-key.pem \
    --embed-certs=true \
    --kubeconfig=${node_hostname}.conf

  kubectl config set-context "system:node:${node_hostname}@${cluster_name}" \
    --cluster=${cluster_name} \
    --user=system:node:${node_hostname} \
    --kubeconfig=${node_hostname}.conf

  kubectl config use-context "system:node:${node_hostname}@${cluster_name}" --kubeconfig=${node_hostname}.conf
done

# ---

# The kube-proxy Kubernetes Configuration File

kubectl config set-cluster ${cluster_name} \
  --certificate-authority=../certs/ca.pem \
  --embed-certs=true \
  --server=https://${public_ip}:6443 \
  --kubeconfig=proxy.conf

kubectl config set-credentials system:kube-proxy \
  --client-certificate=../certs/kube-proxy.pem \
  --client-key=../certs/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=proxy.conf

kubectl config set-context "system:kube-proxy@${cluster_name}" \
  --cluster=${cluster_name} \
  --user=system:kube-proxy \
  --kubeconfig=proxy.conf

kubectl config use-context "system:kube-proxy@${cluster_name}" --kubeconfig=proxy.conf

# ---

# The kube-controller-manager Kubernetes Configuration File

kubectl config set-cluster ${cluster_name} \
  --certificate-authority=../certs/ca.pem \
  --embed-certs=true \
  --server=https://${public_ip}:6443 \
  --kubeconfig=controller-manager.conf

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=../certs/kube-controller-manager.pem \
  --client-key=../certs/kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=controller-manager.conf

kubectl config set-context "system:kube-controller-manager@${cluster_name}" \
  --cluster=${cluster_name} \
  --user=system:kube-controller-manager \
  --kubeconfig=controller-manager.conf

kubectl config use-context "system:kube-controller-manager@${cluster_name}" --kubeconfig=controller-manager.conf

# ---

# The kube-scheduler Kubernetes Configuration File

kubectl config set-cluster ${cluster_name} \
  --certificate-authority=../certs/ca.pem \
  --embed-certs=true \
  --server=https://${public_ip}:6443 \
  --kubeconfig=scheduler.conf

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=../certs/kube-scheduler.pem \
  --client-key=../certs/kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=scheduler.conf

kubectl config set-context "system:kube-scheduler@${cluster_name}" \
  --cluster=${cluster_name} \
  --user=system:kube-scheduler \
  --kubeconfig=scheduler.conf

kubectl config use-context "system:kube-scheduler@${cluster_name}" --kubeconfig=scheduler.conf

# ---

# The admin Kubernetes Configuration File

kubectl config set-cluster ${cluster_name} \
  --certificate-authority=../certs/ca.pem \
  --embed-certs=true \
  --server=https://${public_ip}:6443 \
  --kubeconfig=admin.conf

kubectl config set-credentials kubernetes-admin \
  --client-certificate=../certs/admin.pem \
  --client-key=../certs/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=admin.conf

kubectl config set-context "kubernetes-admin@${cluster_name}" \
  --cluster=${cluster_name} \
  --user=kubernetes-admin \
  --kubeconfig=admin.conf

kubectl config use-context "kubernetes-admin@${cluster_name}" --kubeconfig=admin.conf

