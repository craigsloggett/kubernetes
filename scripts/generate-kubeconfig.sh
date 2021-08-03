#!/usr/bin/env bash

# Configuration Parameters

source "$(dirname -- "$0")/env.sh"

# Run this in a subshell to avoid having to deal with changing directories.
generate_kubeconfig() (
	local conf_dir="$(dirname -- "$0")/.output/kubeconfig"
	local cert_dir="$(dirname -- "$0")/.output/certs"
	
	# Get the absolute value of the certificate directory.
	[ -d "$cert_dir" ] || exit
	cert_dir="$(cd "$cert_dir" || exit; pwd)"
	
	# Create a place to store the configuration files.
	[ ! -d "$conf_dir" ] && mkdir -p "$conf_dir"
	cd "$conf_dir" || exit
	
	# ---
	
	# The kube-controller-manager Kubernetes Configuration File
	
	kubectl config set-cluster "${CLUSTER_NAME}" \
	  --certificate-authority="${cert_dir}/ca.pem" \
	  --embed-certs=true \
	  --server="https://${PUBLIC_IP}:6443" \
	  --kubeconfig=kube-controller-manager.conf
	
	kubectl config set-credentials system:kube-controller-manager \
	  --client-certificate="${cert_dir}/kube-controller-manager.pem" \
	  --client-key="${cert_dir}/kube-controller-manager-key.pem" \
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
	  --certificate-authority="${cert_dir}/ca.pem" \
	  --embed-certs=true \
	  --server="https://${PUBLIC_IP}:6443" \
	  --kubeconfig=kube-scheduler.conf
	
	kubectl config set-credentials system:kube-scheduler \
	  --client-certificate="${cert_dir}/kube-scheduler.pem" \
	  --client-key="${cert_dir}/kube-scheduler-key.pem" \
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
	    --certificate-authority="${cert_dir}/ca.pem" \
	    --embed-certs=true \
	    --server="https://${PUBLIC_IP}:6443" \
	    --kubeconfig="${node_hostname}-kubelet.conf"
	
	  kubectl config set-credentials "system:node:${node_hostname}" \
	    --client-certificate="${cert_dir}/${node_hostname}.pem" \
	    --client-key="${cert_dir}/${node_hostname}-key.pem" \
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
	  --certificate-authority="${cert_dir}/ca.pem" \
	  --embed-certs=true \
	  --server="https://${PUBLIC_IP}:6443" \
	  --kubeconfig=kube-proxy.conf
	
	kubectl config set-credentials system:kube-proxy \
	  --client-certificate="${cert_dir}/kube-proxy.pem" \
	  --client-key="${cert_dir}/kube-proxy-key.pem" \
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
	  --certificate-authority="${cert_dir}/ca.pem" \
	  --embed-certs=true \
	  --server="https://${PUBLIC_IP}:6443" \
	  --kubeconfig=admin.conf
	
	kubectl config set-credentials admin \
	  --client-certificate="${cert_dir}/admin.pem" \
	  --client-key="${cert_dir}/admin-key.pem" \
	  --embed-certs=true \
	  --kubeconfig=admin.conf
	
	kubectl config set-context "admin@${CLUSTER_NAME}" \
	  --cluster="${CLUSTER_NAME}" \
	  --user=admin \
	  --kubeconfig=admin.conf
	
	kubectl config use-context "admin@${CLUSTER_NAME}" --kubeconfig=admin.conf
)

