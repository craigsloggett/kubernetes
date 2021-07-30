#!/usr/bin/env bash

# Configuration Parameters

source env.sh

# Verify the certificates have been created.
[ -d "../certs" ] || exit

# Create a place to store the configuration files.
[ ! -d "../config" ] && mkdir "../config"
cd "../config" || exit

# ---

# Kubernetes API Server Configuration Parameters

#config_directory="/etc/kubernetes"
#pki_directory="/etc/kubernetes/pki"
#service_cluster_ip_range="10.96.0.0/12"
#advertise_address="192.168.1.110"

# Kubernetes API Server

cat > kube-apiserver.service <<- EOF
	[Unit]
	Description=Kubernetes API Server
	Documentation=https://github.com/kubernetes/kubernetes
	
	[Service]
	ExecStart=/usr/local/bin/kube-apiserver \\
	  --advertise-address=${ADVERTISE_ADDRESS} \\
	  --allow-privileged=true \\
	  --apiserver-count=1 \\
	  --audit-log-maxage=30 \\
	  --audit-log-maxbackup=3 \\
	  --audit-log-maxsize=100 \\
	  --audit-log-path=/var/log/audit.log \\
	  --authorization-mode=Node,RBAC \\
	  --bind-address=0.0.0.0 \\
	  --client-ca-file=${PKI_DIRECTORY}/ca.crt \\
	  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
	  --encryption-provider-config=${CONFIG_DIRECTORY}/encryption-config.yaml \\
	  --etcd-cafile=${PKI_DIRECTORY}/etcd/ca.crt \\
	  --etcd-certfile=${PKI_DIRECTORY}/etcd/server.crt \\
	  --etcd-keyfile=${PKI_DIRECTORY}/etcd/server.key \\
	  --etcd-servers=https://127.0.0.1:2379 \\
	  --event-ttl=1h \\
	  --insecure-port=0 \\
	  --kubelet-certificate-authority=${PKI_DIRECTORY}/ca.crt \\
	  --kubelet-client-certificate=${PKI_DIRECTORY}/apiserver.crt \\
	  --kubelet-client-key=${PKI_DIRECTORY}/apiserver.key \\
	  --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname \\
	  --secure-port=6443 \\
	  --service-account-issuer=https://kubernetes.default.svc.cluster.local \\
	  --service-account-key-file=${PKI_DIRECTORY}/sa.crt \\
	  --service-account-signing-key-file=${PKI_DIRECTORY}/sa.key \\
	  --service-cluster-ip-range=${SERVICE_CLUSTER_IP_RANGE} \\
	  --tls-cert-file=${PKI_DIRECTORY}/apiserver.crt \\
	  --tls-private-key-file=${PKI_DIRECTORY}/apiserver.key \\
	  --anonymous-auth=false \\
	  --external-hostname=${ADVERTISE_ADDRESS} \\
	  --runtime-config='api/all=true' \\
	  --service-node-port-range=30000-32767 \\
	  --v=2
	Restart=on-failure
	RestartSec=5
	
	[Install]
	WantedBy=multi-user.target
EOF

# ---

# Kubernetes Controller Manager Configuration Parameters

#config_directory="/etc/kubernetes"       # Duplicated above.
#kubeconfig_directory="/etc/kubernetes"
#pki_directory="/etc/kubernetes/pki"      # Duplicated above.
#service_cluster_ip_range="10.96.0.0/12"  # Duplicated above.

# Kubernetes Controller Manager

cat > kube-controller-manager.service <<- EOF
	[Unit]
	Description=Kubernetes Controller Manager
	Documentation=https://github.com/kubernetes/kubernetes
	
	[Service]
	ExecStart=/usr/local/bin/kube-controller-manager \\
	  --bind-address=0.0.0.0 \\
	  --client-ca-file=${PKI_DIRECTORY}/ca.crt \\
	  --cluster-name=kubernetes \\
	  --cluster-signing-cert-file=${PKI_DIRECTORY}/ca.crt \\
	  --cluster-signing-key-file=${PKI_DIRECTORY}/ca.key \\
	  --kubeconfig=${KUBECONFIG_DIRECTORY}/kube-controller-manager.conf \\
	  --leader-elect=true \\
	  --port=0 \\
	  --root-ca-file=${PKI_DIRECTORY}/ca.crt \\
	  --service-account-private-key-file=${PKI_DIRECTORY}/sa.key \\
	  --service-cluster-ip-range=${SERVICE_CLUSTER_IP_RANGE} \\
	  --use-service-account-credentials=true \\
	  --v=2
	Restart=on-failure
	RestartSec=5
	
	[Install]
	WantedBy=multi-user.target
EOF

# ---

# Kubernetes Scheduler Configuration Parameters

#config_directory="/etc/kubernetes"      # Duplicated above.
#kubeconfig_directory="/etc/kubernetes"  # Duplicated above.

# Kubernetes Scheduler

cat > kube-scheduler.yaml <<- EOF
	apiVersion: kubescheduler.config.k8s.io/v1beta1
	kind: KubeSchedulerConfiguration
	clientConnection:
	  kubeconfig: "${KUBECONFIG_DIRECTORY}/kube-scheduler.conf"
	leaderElection:
	  leaderElect: true
EOF

cat > kube-scheduler.service <<- EOF
	[Unit]
	Description=Kubernetes Scheduler
	Documentation=https://github.com/kubernetes/kubernetes
	
	[Service]
	ExecStart=/usr/local/bin/kube-scheduler \\
	  --config=${CONFIG_DIRECTORY}/kube-scheduler.yaml \\
	  --v=2
	Restart=on-failure
	RestartSec=5
	
	[Install]
	WantedBy=multi-user.target
EOF

# ---

# Kubernetes Kubelet

#config_directory="/etc/kubernetes"      # Duplicated above.
#kubeconfig_directory="/etc/kubernetes"  # Duplicated above.
#pki_directory="/etc/kubernetes/pki"     # Duplicated above.
#dns_service_ip="10.96.0.10"
#pod_infra_container_image="k8s.gcr.io/pause:3.4.1"

for node_hostname in "${NODE_HOSTNAMES[@]}"; do
	cat > "${node_hostname}-kubelet.yaml" <<- EOF
		kind: KubeletConfiguration
		apiVersion: kubelet.config.k8s.io/v1beta1
		authentication:
		  anonymous:
		    enabled: false
		  webhook:
		    enabled: true
		    cacheTTL: 0s
		  x509:
		    clientCAFile: "${PKI_DIRECTORY}/ca.crt"
		authorization:
		  mode: Webhook
		  webhook:
		    cacheAuthorizedTTL: 0s
		    cacheUnauthorizedTTL: 0s
		cgroupDriver: "systemd"
		clusterDomain: "cluster.local"
		clusterDNS:
		  - "${DNS_SERVICE_IP}"
		resolvConf: "/run/systemd/resolve/resolv.conf"
		runtimeRequestTimeout: "15m"
		tlsCertFile: "${PKI_DIRECTORY}/${node_hostname}.crt"
		tlsPrivateKeyFile: "${PKI_DIRECTORY}/${node_hostname}.key"
	EOF
done

# NOTE: It is assumed that the kubeconfig and config files are named to 
#       kubelet.conf and kubelet.yaml respectively once copied to the 
#       appropriate host.
cat > kubelet.service <<- EOF
	[Unit]
	Description=Kubernetes Kubelet
	Documentation=https://github.com/kubernetes/kubernetes
	
	[Service]
	ExecStart=/usr/local/bin/kubelet \\
	  --config=${CONFIG_DIRECTORY}/kubelet.yaml \\
	  --container-runtime=remote \\
	  --container-runtime-endpoint='/var/run/crio/crio.sock' \\
	  --kubeconfig=${KUBECONFIG_DIRECTORY}/kubelet.conf \\
	  --pod-infra-container-image='${POD_INFRA_CONTAINER_IMAGE}' \\
	  --v=2
	Restart=on-failure
	RestartSec=5
	
	[Install]
	WantedBy=multi-user.target
EOF

# ---

# Kubernetes Proxy

#config_directory="/etc/kubernetes"      # Duplicated above.
#kubeconfig_directory="/etc/kubernetes"  # Duplicated above.

cat > kube-proxy.yaml <<- EOF
	kind: KubeProxyConfiguration
	apiVersion: kubeproxy.config.k8s.io/v1alpha1
	clientConnection:
	  kubeconfig: "${KUBECONFIG_DIRECTORY}/kube-proxy.conf"
	mode: "ipvs"
EOF

cat > kube-proxy.service <<- EOF
	[Unit]
	Description=Kubernetes Kube Proxy
	Documentation=https://github.com/kubernetes/kubernetes
	
	[Service]
	ExecStart=/usr/local/bin/kube-proxy \\
	  --config=${CONFIG_DIRECTORY}/kube-proxy.yaml
	Restart=on-failure
	RestartSec=5
	
	[Install]
	WantedBy=multi-user.target
EOF

