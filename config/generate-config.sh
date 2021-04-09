#!/usr/bin/env bash

# Configuration Parameters

etcd_server_ip="192.168.1.110"
api_server_ip="192.168.1.110"
pod_ip_range="10.200.0.0/16"
service_ip_range="10.32.0.0/24"

config_directory="/etc/kubernetes"
pki_directory="/etc/kubernetes/pki"
etcd_tls_directory="/etc/etcd/tls"
kubeconfig_directory="/etc/kubernetes/kubeconfig"

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
	  --service-cluster-ip-range=${service_ip_range} \\
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
	  --bind-address=0.0.0.0 \\
	  --cluster-cidr=${pod_ip_range} \\
	  --cluster-name=kubernetes \\
	  --cluster-signing-cert-file=${pki_directory}/ca.pem \\
	  --cluster-signing-key-file=${pki_directory}/ca-key.pem \\
	  --kubeconfig=${kubeconfig_directory}/kube-controller-manager.kubeconfig \\
	  --leader-elect=true \\
	  --root-ca-file=${pki_directory}/ca.pem \\
	  --node-cidr-mask-size=23 \\
	  --service-account-private-key-file=${pki_directory}/service-account-key.pem \\
	  --service-cluster-ip-range=${service_ip_range} \\
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

cat > kubelet.service <<- EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/etc/kubernetes/kubelet-config.yaml \\
  --cgroup-driver=systemd \\
  --container-runtime=remote \\
  --container-runtime-endpoint='unix:///var/run/crio/crio.sock' \\
  --kubeconfig=/etc/kubernetes/kubeconfig/kubelet.kubeconfig \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
	[Unit]
	Description=Kubernetes Kubelet
	Documentation=https://github.com/kubernetes/kubernetes
	
	[Service]
	ExecStart=/usr/bin/kubelet \\
	  --allow-privileged=true \\
	  --api-servers=https://10.0.1.94:6443,https://10.0.1.95:6443,https://10.0.1.96:6443 \\
	  --cloud-provider= \\
	  --cluster-dns=10.32.0.10 \\
	  --cluster-domain=cluster.local \\
	  --configure-cbr0=true \\
	  --container-runtime=docker \\
	  --docker=unix:///var/run/docker.sock \\
	  --network-plugin=kubenet \\
	  --kubeconfig=/var/lib/kubelet/kubeconfig \\
	  --reconcile-cidr=true \\
	  --serialize-image-pulls=false \\
	  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
	  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
	  --v=2
	  
	Restart=on-failure
	RestartSec=5
	
	[Install]
	WantedBy=multi-user.target
EOF
