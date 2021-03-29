#!/usr/bin/env bash

# Configuration Parameters

country="CA"
province="Ontario"
location="Hamilton"

controller_hostnames=("k8s-controller-0")
node_hostnames=("k8s-node-0" "k8s-node-1" "k8s-node-2")

controller_0_ip="192.168.1.110"
node_0_ip="192.168.1.120"
node_1_ip="192.168.1.121"
node_2_ip="192.168.1.122"

internal_cluster_dns_ip="10.32.0.1"

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
	  "CN": "Kubernetes",
	  "key": {
	    "algo": "rsa",
	    "size": 2048
	  },
	  "names": [
	    {
	      "C": "$country",
	      "ST": "$province",
	      "L": "$location",
	      "O": "Kubernetes",
	      "OU": "CA"
	    }
	  ]
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
	  },
	  "names": [
	    {
	      "C": "$country",
	      "ST": "$province",
	      "L": "$location",
	      "O": "system:masters",
	      "OU": "Kubernetes"
	    }
	  ]
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
	cat > ${node_hostname}-csr.json <<- EOF
		{
		  "CN": "system:node:${node_hostname}",
		  "key": {
		    "algo": "rsa",
		    "size": 2048
		  },
		  "names": [
		    {
		      "C": "$country",
		      "ST": "$province",
		      "L": "$location",
		      "O": "system:nodes",
		      "OU": "Kubernetes"
		    }
		  ]
		}
	EOF

	# Get the variable name containing the IP of the given hostname.
	node_ip_ref="$( printf '%s\n' "${node_hostname##k8s-}_ip" | tr '-' '_' )"

	cfssl gencert \
		-ca=ca.pem \
		-ca-key=ca-key.pem \
		-config=ca-config.json \
		-hostname=${node_hostname},${!node_ip_ref} \
		-profile=kubernetes \
		${node_hostname}-csr.json | cfssljson -bare ${node_hostname}
done

# ---

# The Controller Manager Client Certificate

cat > kube-controller-manager-csr.json <<- EOF
	{
	  "CN": "system:kube-controller-manager",
	  "key": {
	    "algo": "rsa",
	    "size": 2048
	  },
		"names": [
		  {
		    "C": "$country",
		    "ST": "$province",
		    "L": "$location",
		    "O": "system:kube-controller-manager",
		    "OU": "Kubernetes"
		  }
	  ]
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
	  },
		"names": [
		  {
		    "C": "$country",
		    "ST": "$province",
		    "L": "$location",
		    "O": "system:node-proxier",
		    "OU": "Kubernetes"
		  }
	  ]
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
	  },
		"names": [
		  {
		    "C": "$country",
		    "ST": "$province",
		    "L": "$location",
		    "O": "system:kube-scheduler",
		    "OU": "Kubernetes"
		  }
	  ]
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

KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > kubernetes-csr.json <<- EOF
	{
	  "CN": "kubernetes",
	  "key": {
	    "algo": "rsa",
	    "size": 2048
	  },
	  "names": [
	    {
		    "C": "$country",
		    "ST": "$province",
		    "L": "$location",
	      "O": "Kubernetes",
		    "OU": "Kubernetes"
	    }
	  ]
	}
EOF


# Put the node IPs/hostnames on a single line, comma seperated.
for node_hostname in "${node_hostnames[@]}"; do
	# Get the variable name containing the IP of the given hostname.
	node_ip_ref="$( printf '%s\n' "${node_hostname##k8s-}_ip" | tr '-' '_' )"
	# Generate the lists of IPs and hostnames.
	node_ip_list="${node_ip_list:+${node_ip_list},}${!node_ip_ref}"
done

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname="${internal_cluster_dns_ip}","${node_ip_list}",127.0.0.1,"${KUBERNETES_HOSTNAMES}" \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

# ---

# The Service Account Key Pair

cat > service-account-csr.json <<EOF
	{
	  "CN": "service-accounts",
	  "key": {
	    "algo": "rsa",
	    "size": 2048
	  },
	  "names": [
	    {
	      "C": "$country",
	      "ST": "$province",
	      "L": "$location",
	      "O": "Kubernetes",
	      "OU": "Kubernetes"
	    }
	  ]
	}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

