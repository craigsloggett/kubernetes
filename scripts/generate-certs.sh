#!/usr/bin/env bash

# Configuration Parameters

controller_hostname="controller-0"
controller_ip="192.168.1.110"
internal_cluster_dns_ip="10.96.0.1"

# I've implemented a poor man's key:value store
# so the variable names align with the hostnames
# set below. The keys are determined dynamically
# in a loop, so the variable names aren't used
# explicitly -- disabling SC2034 as a result.

node_hostnames=("node-0" "node-1" "node-2")
# shellcheck disable=SC2034
node_0_ip="192.168.1.120"
# shellcheck disable=SC2034
node_1_ip="192.168.1.121"
# shellcheck disable=SC2034
node_2_ip="192.168.1.122"

# Create a place to store the certificate files.
[ ! -d "../certs" ] && mkdir "../certs"
cd "../certs" || exit

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
	  "CN": "admin",
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

for node_hostname in "${node_hostnames[@]}"; do
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
	node_ip_ref="$( printf '%s\n' "${node_hostname}_ip" | tr '-' '_' )"

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

DEFAULT_KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.svc.cluster.local

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
  -hostname="${controller_hostname}","${DEFAULT_KUBERNETES_HOSTNAMES}","${internal_cluster_dns_ip}","${controller_ip}" \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

# ---

# The Service Account Key Pair

cat > service-account-csr.json <<- EOF
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
  service-account-csr.json | cfssljson -bare service-account

