#!/usr/bin/env bash

set -euo pipefail

# Configuration Parameters

source "$(dirname -- "$0")/env.sh"

# Check if the required tooling is installed.
if ! command -v cfssl > /dev/null; then
	printf '%s\n' "cfssl is required but not installed."
	exit
fi

# Run this in a subshell to avoid having to deal with changing directories.
generate_certs() (
	# Create a place to store the certificate files.
	[ ! -d "$CERT_DIR" ] && mkdir -p "$CERT_DIR"
	cd "$CERT_DIR" || exit

	# ---

	# Certificate Authority

	cat > ca-config.json <<- EOF
		{
		  "signing": {
		    "default": {
		      "expiry": "8760h"
		    },
		    "profiles": {
		      "kubernetes": {
		        "usages": ["signing", "key encipherment", "server auth", "client auth"],
		        "expiry": "8760h"
		      }
		    }
		  }
		}
	EOF

	cat > ca-csr.json <<- EOF
		{
		  "CN": "kubernetes",
		  "key": {
		    "algo": "rsa",
		    "size": 2048
		  }
		}
	EOF

	cfssl gencert -loglevel=5 -initca ca-csr.json | cfssljson -bare ca

	# ---

	# The Admin Client Certificate

	cat > admin-csr.json <<- EOF
		{
		  "CN": "admin",
		  "key": {
		    "algo": "rsa",
		    "size": 2048
		  },
		      "names": [
		        {
		          "O": "system:masters"
		        }
		      ]
		}
	EOF

	cfssl gencert \
		-ca=ca.pem \
		-ca-key=ca-key.pem \
		-config=ca-config.json \
		-profile=kubernetes \
		-loglevel=5 \
		admin-csr.json | cfssljson -bare admin

	# ---

	# The Kubelet Client Certificates

	for node_hostname in "${NODE_HOSTNAMES[@]}"; do
		cat > "${node_hostname}-csr.json" <<- EOF
			{
			  "CN": "system:node:${node_hostname}",
			  "key": {
			    "algo": "rsa",
			    "size": 2048
			  }
			}
		EOF
		# Get the variable name containing the IP of the given hostname.
		node_ip_ref="$(printf '%s\n' "${node_hostname}_IP" | tr '-' '_' | tr '[:lower:]' '[:upper:]')"

		cfssl gencert \
			-ca=ca.pem \
			-ca-key=ca-key.pem \
			-config=ca-config.json \
			-hostname="${node_hostname},${!node_ip_ref}" \
			-profile=kubernetes \
			-loglevel=5 \
			"${node_hostname}-csr.json" | cfssljson -bare "${node_hostname}"
	done

	# ---

	# The Controller Manager Client Certificate

	cat > kube-controller-manager-csr.json <<- EOF
		{
		  "CN": "system:kube-controller-manager",
		  "key": {
		    "algo": "rsa",
		    "size": 2048
		  }
		}
	EOF

	cfssl gencert \
		-ca=ca.pem \
		-ca-key=ca-key.pem \
		-config=ca-config.json \
		-profile=kubernetes \
		-loglevel=5 \
		kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

	# ---

	# The Kube Proxy Client Certificate

	cat > kube-proxy-csr.json <<- EOF
		{
		  "CN": "system:kube-proxy",
		  "key": {
		    "algo": "rsa",
		    "size": 2048
		  }
		}
	EOF

	cfssl gencert \
		-ca=ca.pem \
		-ca-key=ca-key.pem \
		-config=ca-config.json \
		-profile=kubernetes \
		-loglevel=5 \
		kube-proxy-csr.json | cfssljson -bare kube-proxy

	# ---

	# The Scheduler Client Certificate

	cat > kube-scheduler-csr.json <<- EOF
		{
		  "CN": "system:kube-scheduler",
		  "key": {
		    "algo": "rsa",
		    "size": 2048
		  }
		}
	EOF

	cfssl gencert \
		-ca=ca.pem \
		-ca-key=ca-key.pem \
		-config=ca-config.json \
		-profile=kubernetes \
		-loglevel=5 \
		kube-scheduler-csr.json | cfssljson -bare kube-scheduler

	# ---

	# The Kubernetes API Server Certificate

	default_kubernetes_hostnames=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.svc.cluster.local

	cat > kubernetes-csr.json <<- EOF
		{
		  "CN": "kubernetes",
		  "key": {
		    "algo": "rsa",
		    "size": 2048
		  }
		}
	EOF

	cfssl gencert \
		-ca=ca.pem \
		-ca-key=ca-key.pem \
		-config=ca-config.json \
		-hostname="${CONTROLLER_HOSTNAME}","${default_kubernetes_hostnames}","${INTERNAL_CLUSTER_DNS_IP}","${CONTROLLER_IP}",127.0.0.1 \
		-profile=kubernetes \
		-loglevel=5 \
		kubernetes-csr.json | cfssljson -bare kubernetes

	# ---

	# The Service Account Key Pair

	cat > sa-csr.json <<- EOF
		{
		  "CN": "service-accounts",
		  "key": {
		    "algo": "rsa",
		    "size": 2048
		  }
		}
	EOF

	cfssl gencert \
		-ca=ca.pem \
		-ca-key=ca-key.pem \
		-config=ca-config.json \
		-profile=kubernetes \
		-loglevel=5 \
		sa-csr.json | cfssljson -bare sa
)

generate_certs
