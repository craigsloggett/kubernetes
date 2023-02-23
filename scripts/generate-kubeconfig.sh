#!/usr/bin/env bash

set -euo pipefail

# Configuration Parameters

source "$(dirname -- "$0")/env.sh"

# Check if the required tooling is installed.
if ! command -v kubectl > /dev/null; then
	printf '%s\n' "kubectl is required but not installed."
	exit
fi

# Run this in a subshell to avoid having to deal with changing directories.
generate_kubeconfig() (
	# Get the absolute value of the certificate directory.
	[ -d "$CERT_DIR" ] || exit
	CERT_DIR="$(
		cd "$CERT_DIR" || exit
		pwd
	)"

	# Create a place to store the configuration files.
	[ ! -d "$KUBECONFIG_DIR" ] && mkdir -p "$KUBECONFIG_DIR"
	cd "$KUBECONFIG_DIR" || exit

	# ---

	# The kube-controller-manager Kubernetes Configuration File

	kubectl config set-cluster "${CLUSTER_NAME}" \
		--certificate-authority="${CERT_DIR}/ca.pem" \
		--embed-certs=true \
		--server="https://${PUBLIC_IP}:6443" \
		--kubeconfig=controller-manager.conf > /dev/null

	kubectl config set-credentials system:kube-controller-manager \
		--client-certificate="${CERT_DIR}/kube-controller-manager.pem" \
		--client-key="${CERT_DIR}/kube-controller-manager-key.pem" \
		--embed-certs=true \
		--kubeconfig=controller-manager.conf > /dev/null

	kubectl config set-context "system:kube-controller-manager@${CLUSTER_NAME}" \
		--cluster="${CLUSTER_NAME}" \
		--user=system:kube-controller-manager \
		--kubeconfig=controller-manager.conf > /dev/null

	kubectl config use-context "system:kube-controller-manager@${CLUSTER_NAME}" --kubeconfig=controller-manager.conf > /dev/null

	# ---

	# The kube-scheduler Kubernetes Configuration File

	kubectl config set-cluster "${CLUSTER_NAME}" \
		--certificate-authority="${CERT_DIR}/ca.pem" \
		--embed-certs=true \
		--server="https://${PUBLIC_IP}:6443" \
		--kubeconfig=scheduler.conf > /dev/null

	kubectl config set-credentials system:kube-scheduler \
		--client-certificate="${CERT_DIR}/kube-scheduler.pem" \
		--client-key="${CERT_DIR}/kube-scheduler-key.pem" \
		--embed-certs=true \
		--kubeconfig=scheduler.conf > /dev/null

	kubectl config set-context "system:kube-scheduler@${CLUSTER_NAME}" \
		--cluster="${CLUSTER_NAME}" \
		--user=system:kube-scheduler \
		--kubeconfig=scheduler.conf > /dev/null

	kubectl config use-context "system:kube-scheduler@${CLUSTER_NAME}" --kubeconfig=scheduler.conf > /dev/null

	# ---

	# The kubelet Kubernetes Configuration File

	for node_hostname in "${NODE_HOSTNAMES[@]}"; do
		kubectl config set-cluster "${CLUSTER_NAME}" \
			--certificate-authority="${CERT_DIR}/ca.pem" \
			--embed-certs=true \
			--server="https://${PUBLIC_IP}:6443" \
			--kubeconfig="${node_hostname}-kubelet.conf" > /dev/null

		kubectl config set-credentials "system:node:${node_hostname}" \
			--client-certificate="${CERT_DIR}/${node_hostname}.pem" \
			--client-key="${CERT_DIR}/${node_hostname}-key.pem" \
			--embed-certs=true \
			--kubeconfig="${node_hostname}-kubelet.conf" > /dev/null

		kubectl config set-context "system:node:${node_hostname}@${CLUSTER_NAME}" \
			--cluster="${CLUSTER_NAME}" \
			--user="system:node:${node_hostname}" \
			--kubeconfig="${node_hostname}-kubelet.conf" > /dev/null

		kubectl config use-context "system:node:${node_hostname}@${CLUSTER_NAME}" --kubeconfig="${node_hostname}-kubelet.conf" > /dev/null
	done

	# ---

	# The kube-proxy Kubernetes Configuration File

	kubectl config set-cluster "${CLUSTER_NAME}" \
		--certificate-authority="${CERT_DIR}/ca.pem" \
		--embed-certs=true \
		--server="https://${PUBLIC_IP}:6443" \
		--kubeconfig=proxy.conf > /dev/null

	kubectl config set-credentials system:kube-proxy \
		--client-certificate="${CERT_DIR}/kube-proxy.pem" \
		--client-key="${CERT_DIR}/kube-proxy-key.pem" \
		--embed-certs=true \
		--kubeconfig=proxy.conf > /dev/null

	kubectl config set-context "system:kube-proxy@${CLUSTER_NAME}" \
		--cluster="${CLUSTER_NAME}" \
		--user=system:kube-proxy \
		--kubeconfig=proxy.conf > /dev/null

	kubectl config use-context "system:kube-proxy@${CLUSTER_NAME}" --kubeconfig=proxy.conf > /dev/null

	# ---

	# The admin Kubernetes Configuration File

	kubectl config set-cluster "${CLUSTER_NAME}" \
		--certificate-authority="${CERT_DIR}/ca.pem" \
		--embed-certs=true \
		--server="https://${PUBLIC_IP}:6443" \
		--kubeconfig=admin.conf > /dev/null

	kubectl config set-credentials admin \
		--client-certificate="${CERT_DIR}/admin.pem" \
		--client-key="${CERT_DIR}/admin-key.pem" \
		--embed-certs=true \
		--kubeconfig=admin.conf > /dev/null

	kubectl config set-context "admin@${CLUSTER_NAME}" \
		--cluster="${CLUSTER_NAME}" \
		--user=admin \
		--kubeconfig=admin.conf > /dev/null

	kubectl config use-context "admin@${CLUSTER_NAME}" --kubeconfig=admin.conf > /dev/null
)

generate_kubeconfig
