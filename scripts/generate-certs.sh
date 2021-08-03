#!/usr/bin/env bash

# Configuration Parameters

source "$(dirname -- "$0")/env.sh"

# Run this in a subshell to avoid having to deal with changing directories.
generate_certs() (
	local cert_dir="$(dirname -- "$0")/.output/certs"
	
	# Create a place to store the certificate files.
	[ ! -d "$cert_dir" ] && mkdir -p "$cert_dir"
	cd "$cert_dir" || exit
	
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
	
	cfssl gencert -initca ca-csr.json | cfssljson -bare ca
	
	# ---
	
	# The Admin Client Certificate
	
	cat > admin-csr.json <<- EOF
		{
		  "CN": "system:masters:admin",
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
		node_ip_ref="$( printf '%s\n' "${node_hostname}_IP" | tr '-' '_' | tr '[:lower:]' '[:upper:]' )"
	
		cfssl gencert \
			-ca=ca.pem \
			-ca-key=ca-key.pem \
			-config=ca-config.json \
			-hostname="${node_hostname},${!node_ip_ref}" \
			-profile=kubernetes \
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
	  sa-csr.json | cfssljson -bare sa
)

