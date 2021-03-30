#!/usr/bin/env bash

# Configuration Parameters

etcd_server_ip="192.168.1.110"
api_server_ip="192.168.1.110"
pod_ip_range="10.200.0.0/16"
service_ip_range="10.32.0.0/24"

config_directory="/etc/kubernetes"
pki_directory="/etc/kubernetes/pki"
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
	  --apiserver-count=1 \\
	  --audit-log-maxage=30 \\
	  --audit-log-maxbackup=3 \\
	  --audit-log-maxsize=100 \\
	  --audit-log-path=/var/log/audit.log \\
	  --authorization-mode=Node,RBAC \\
	  --bind-address=0.0.0.0 \\
	  --client-ca-file=${pki_directory}/ca.pem \\
	  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
	  --etcd-cafile=${pki_directory}/ca.pem \\
	  --etcd-certfile=${pki_directory}/kubernetes.pem \\
	  --etcd-keyfile=${pki_directory}/kubernetes-key.pem \\
	  --etcd-servers=https://${etcd_server_ip}:2379 \\
	  --event-ttl=1h \\
	  --encryption-provider-config=${config_directory}/encryption-config.yaml \\
	  --kubelet-certificate-authority=${pki_directory}/ca.pem \\
	  --kubelet-client-certificate=${pki_directory}/kubernetes.pem \\
	  --kubelet-client-key=${pki_directory}/kubernetes-key.pem \\
	  --kubelet-https=true \\
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
	apiVersion: kubescheduler.config.k8s.io/v1alpha1
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
