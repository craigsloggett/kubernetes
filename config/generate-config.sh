#!/usr/bin/env bash

# Configuration Parameters

etcd_server_ip="192.168.1.110"
api_server_ip="192.168.1.110"
pod_cidr="10.200.0.0/16"
service_cidr="10.32.0.0/24"

config_directory="/etc/kubernetes"
pki_directory="/etc/kubernetes/pki"
etcd_tls_directory="/etc/etcd/tls"
kubeconfig_directory="/etc/kubernetes/kubeconfig"

node_hostnames=("node-0" "node-1" "node-2")
cluster_name="kubernetes-pi"

pod_infra_container_image="gcr.io/google-containers/pause-arm64:3.2"
# ---

# Kubernetes API Server

cat > kube-apiserver.service <<- EOF
	[Unit]
	Description=Kubernetes API Server
	Documentation=https://github.com/kubernetes/kubernetes
	
	[Service]
	ExecStart=/usr/local/bin/kube-apiserver \\
	  --advertise-address=${api_server_ip} \\
	  --allow-privileged=true \\
	  --anonymous-auth=false \\
	  --apiserver-count=1 \\
	  --audit-log-maxage=30 \\
	  --audit-log-maxbackup=3 \\
	  --audit-log-maxsize=100 \\
	  --audit-log-path=/var/log/audit.log \\
	  --authorization-mode=Node,RBAC \\
	  --bind-address=0.0.0.0 \\
	  --client-ca-file=${pki_directory}/ca.pem \\
	  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
	  --etcd-cafile=${etcd_tls_directory}/ca.pem \\
	  --etcd-certfile=${etcd_tls_directory}/kubernetes.pem \\
	  --etcd-keyfile=${etcd_tls_directory}/kubernetes-key.pem \\
	  --etcd-servers=https://${etcd_server_ip}:2379 \\
	  --event-ttl=1h \\
	  --encryption-provider-config=${config_directory}/encryption-config.yaml \\
	  --external-hostname=${api_server_ip} \\
	  --kubelet-certificate-authority=${pki_directory}/ca.pem \\
	  --kubelet-client-certificate=${pki_directory}/kubernetes.pem \\
	  --kubelet-client-key=${pki_directory}/kubernetes-key.pem \\
	  --runtime-config='api/all=true' \\
	  --service-account-key-file=${pki_directory}/service-account.pem \\
	  --service-account-signing-key-file=${pki_directory}/service-account-key.pem \\
	  --service-account-issuer=api \\
	  --service-cluster-ip-range=${service_cidr} \\
	  --service-node-port-range=30000-32767 \\
	  --tls-cert-file=${pki_directory}/kubernetes.pem \\
	  --tls-private-key-file=${pki_directory}/kubernetes-key.pem \\
	  --v=2
	Restart=on-failure
	RestartSec=5
	
	[Install]
	WantedBy=multi-user.target
EOF

# ---

# Kubernetes Controller Manager

cat > kube-controller-manager.service <<- EOF
	[Unit]
	Description=Kubernetes Controller Manager
	Documentation=https://github.com/kubernetes/kubernetes
	
	[Service]
	ExecStart=/usr/local/bin/kube-controller-manager \\
	  --allocate-node-cidrs=true \\
	  --bind-address=0.0.0.0 \\
	  --cluster-cidr=${pod_cidr} \\
	  --cluster-name=${cluster_name} \\
	  --cluster-signing-cert-file=${pki_directory}/ca.pem \\
	  --cluster-signing-key-file=${pki_directory}/ca-key.pem \\
	  --kubeconfig=${kubeconfig_directory}/kube-controller-manager.kubeconfig \\
	  --leader-elect=true \\
	  --root-ca-file=${pki_directory}/ca.pem \\
	  --node-cidr-mask-size=23 \\
	  --service-account-private-key-file=${pki_directory}/service-account-key.pem \\
	  --service-cluster-ip-range=${service_cidr} \\
	  --use-service-account-credentials=true \\
	  --v=2
	Restart=on-failure
	RestartSec=5
	
	[Install]
	WantedBy=multi-user.target
EOF

# ---

# Kubernetes Scheduler

cat > kube-scheduler.yaml <<- EOF
	apiVersion: kubescheduler.config.k8s.io/v1beta1
	kind: KubeSchedulerConfiguration
	clientConnection:
	  kubeconfig: "${kubeconfig_directory}/kube-scheduler.kubeconfig"
	leaderElection:
	  leaderElect: true
EOF

cat > kube-scheduler.service <<- EOF
	[Unit]
	Description=Kubernetes Scheduler
	Documentation=https://github.com/kubernetes/kubernetes
	
	[Service]
	ExecStart=/usr/local/bin/kube-scheduler \\
	  --config=${config_directory}/kube-scheduler.yaml \\
	  --v=2
	Restart=on-failure
	RestartSec=5
	
	[Install]
	WantedBy=multi-user.target
EOF

# ---

# Kubernetes Kubelet

for node_hostname in "${node_hostnames[@]}"; do
	cat > ${node_hostname}-kubelet-config.yaml <<- EOF
		kind: KubeletConfiguration
		apiVersion: kubelet.config.k8s.io/v1beta1
		authentication:
		  anonymous:
		    enabled: false
		  webhook:
		    enabled: true
		  x509:
		    clientCAFile: "${pki_directory}/ca.pem"
		authorization:
		  mode: Webhook
		cgroupDriver: "systemd"
		clusterDomain: "cluster.local"
		clusterDNS:
		  - "10.32.0.10"
		resolvConf: "/run/systemd/resolve/resolv.conf"
		runtimeRequestTimeout: "15m"
		tlsCertFile: "${pki_directory}/${node_hostname}.pem"
		tlsPrivateKeyFile: "${pki_directory}/${node_hostname}-key.pem"
	EOF
done

cat > kubelet.service <<- EOF
	[Unit]
	Description=Kubernetes Kubelet
	Documentation=https://github.com/kubernetes/kubernetes
	
	[Service]
	ExecStart=/usr/local/bin/kubelet \\
	  --config=${config_directory}/kubelet-config.yaml \\
	  --container-runtime=remote \\
	  --container-runtime-endpoint='unix:///var/run/crio/crio.sock' \\
	  --kubeconfig=${kubeconfig_directory}/kubelet.kubeconfig \\
	  --pod-infra-container-image='${pod_infra_container_image}' \\
	  --v=2
	Restart=on-failure
	RestartSec=5
	
	[Install]
	WantedBy=multi-user.target
EOF

# Kubernetes Proxy

cat > kube-proxy-config.yaml <<- EOF
	kind: KubeProxyConfiguration
	apiVersion: kubeproxy.config.k8s.io/v1alpha1
	clientConnection:
	  kubeconfig: "${kubeconfig_directory}/kube-proxy.kubeconfig"
	mode: "ipvs"
	clusterCIDR: "${pod_cidr}"
EOF

cat > kube-proxy.service <<- EOF
	[Unit]
	Description=Kubernetes Kube Proxy
	Documentation=https://github.com/kubernetes/kubernetes
	
	[Service]
	ExecStart=/usr/local/bin/kube-proxy \\
	  --config=${config_directory}/kube-proxy-config.yaml
	Restart=on-failure
	RestartSec=5
	
	[Install]
	WantedBy=multi-user.target
EOF
