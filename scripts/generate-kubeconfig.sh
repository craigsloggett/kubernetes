#!/usr/bin/env bash

# Configuration Parameters

source env.sh

#node_hostnames=("node-0" "node-1" "node-2")
#cluster_name="kubernetes"
#public_ip="192.168.1.110"

# Verify the certificates have been created.
[ -d "../certs" ] || exit

# Create a place to store the configuration files.
[ ! -d "../kubeconfig" ] && mkdir "../kubeconfig"
cd "../kubeconfig" || exit

# ---

# The kube-controller-manager Kubernetes Configuration File

kubectl config set-cluster "${CLUSTER_NAME}" \
  --certificate-authority=../certs/ca.pem \
  --embed-certs=true \
  --server="https://${PUBLIC_IP}:6443" \
  --kubeconfig=kube-controller-manager.conf

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=../certs/kube-controller-manager.pem \
  --client-key=../certs/kube-controller-manager-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.conf

kubectl config set-context "system:kube-controller-manager@${CLUSTER_NAME}" \
  --cluster="${CLUSTER_NAME}" \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.conf

kubectl config use-context "system:kube-controller-manager@${CLUSTER_NAME}" --kubeconfig=kube-controller-manager.conf

# ---

# The kube-scheduler Kubernetes Configuration File

kubectl config set-cluster "${CLUSTER_NAME}" \
  --certificate-authority=../certs/ca.pem \
  --embed-certs=true \
  --server="https://${PUBLIC_IP}:6443" \
  --kubeconfig=kube-scheduler.conf

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=../certs/kube-scheduler.pem \
  --client-key=../certs/kube-scheduler-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.conf

kubectl config set-context "system:kube-scheduler@${CLUSTER_NAME}" \
  --cluster="${CLUSTER_NAME}" \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.conf

kubectl config use-context "system:kube-scheduler@${CLUSTER_NAME}" --kubeconfig=kube-scheduler.conf

# ---

# The kubelet Kubernetes Configuration File

for node_hostname in "${NODE_HOSTNAMES[@]}"; do
  kubectl config set-cluster "${CLUSTER_NAME}" \
    --certificate-authority=../certs/ca.pem \
    --embed-certs=true \
    --server="https://${PUBLIC_IP}:6443" \
    --kubeconfig="${node_hostname}-kubelet.conf"

  kubectl config set-credentials "system:node:${node_hostname}" \
    --client-certificate="../certs/${node_hostname}.pem" \
    --client-key="../certs/${node_hostname}-key.pem" \
    --embed-certs=true \
    --kubeconfig="${node_hostname}-kubelet.conf"

  kubectl config set-context "system:node:${node_hostname}@${CLUSTER_NAME}" \
    --cluster="${CLUSTER_NAME}" \
    --user="system:node:${node_hostname}" \
    --kubeconfig="${node_hostname}-kubelet.conf"

  kubectl config use-context "system:node:${node_hostname}@${CLUSTER_NAME}" --kubeconfig="${node_hostname}-kubelet.conf"
done

# ---

# The kube-proxy Kubernetes Configuration File

kubectl config set-cluster "${CLUSTER_NAME}" \
  --certificate-authority=../certs/ca.pem \
  --embed-certs=true \
  --server="https://${PUBLIC_IP}:6443" \
  --kubeconfig=kube-proxy.conf

kubectl config set-credentials system:kube-proxy \
  --client-certificate=../certs/kube-proxy.pem \
  --client-key=../certs/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.conf

kubectl config set-context "system:kube-proxy@${CLUSTER_NAME}" \
  --cluster="${CLUSTER_NAME}" \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.conf

kubectl config use-context "system:kube-proxy@${CLUSTER_NAME}" --kubeconfig=kube-proxy.conf

# ---

# The admin Kubernetes Configuration File

kubectl config set-cluster "${CLUSTER_NAME}" \
  --certificate-authority=../certs/ca.pem \
  --embed-certs=true \
  --server="https://${PUBLIC_IP}:6443" \
  --kubeconfig=admin.conf

kubectl config set-credentials admin \
  --client-certificate=../certs/admin.pem \
  --client-key=../certs/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=admin.conf

kubectl config set-context "admin@${CLUSTER_NAME}" \
  --cluster="${CLUSTER_NAME}" \
  --user=admin \
  --kubeconfig=admin.conf

kubectl config use-context "admin@${CLUSTER_NAME}" --kubeconfig=admin.conf

