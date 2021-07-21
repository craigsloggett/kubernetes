#!/usr/bin/env bash

# Verify the certificates have been created.
[ -d "../certs" ] || exit

# Create a place to store the configuration files.
[ ! -d "../config" ] && mkdir "../config"
cd "../config" || exit

# ---

# Kubernetes API Server Configuration Parameters

config_directory="/etc/kubernetes"
pki_directory="/etc/kubernetes/pki"
advertise_address="192.168.1.110"
service_cluster_ip_range="10.96.0.0/12"

# Kubernetes API Server

cat > kube-apiserver.service <<- EOF
	[Unit]
	Description=Kubernetes API Server
	Documentation=https://github.com/kubernetes/kubernetes
	
	[Service]
	ExecStart=/usr/local/bin/kube-apiserver \\
	  --advertise-address=${advertise_address} \\
	  --allow-privileged=true \\
	  --apiserver-count=1 \\
	  --audit-log-maxage=30 \\
	  --audit-log-maxbackup=3 \\
	  --audit-log-maxsize=100 \\
	  --audit-log-path=/var/log/audit.log \\
	  --authorization-mode=Node,RBAC \\
	  --bind-address=0.0.0.0 \\
	  --client-ca-file=${pki_directory}/ca.crt \\
	  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
	  --encryption-provider-config=${config_directory}/encryption-config.yaml \\
	  --etcd-cafile=${pki_directory}/etcd/ca.crt \\
	  --etcd-certfile=${pki_directory}/etcd/server.crt \\
	  --etcd-keyfile=${pki_directory}/etcd/server.key \\
	  --etcd-servers=https://127.0.0.1:2379 \\
	  --event-ttl=1h \\
	  --insecure-port=0 \\
	  --kubelet-certificate-authority=${pki_directory}/ca.crt \\
	  --kubelet-client-certificate=${pki_directory}/apiserver.crt \\
	  --kubelet-client-key=${pki_directory}/apiserver.key \\
	  --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname \\
	  --secure-port=6443 \\
	  --service-account-issuer=https://kubernetes.default.svc.cluster.local \\
	  --service-account-key-file=${pki_directory}/sa.pub \\
	  --service-account-signing-key-file=${pki_directory}/sa.key \\
	  --service-cluster-ip-range=${service_cluster_ip_range} \\
	  --tls-cert-file=${pki_directory}/apiserver.crt \\
	  --tls-private-key-file=${pki_directory}/apiserver.key \\
	  --anonymous-auth=false \\
	  --external-hostname=${advertise_address} \\
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

config_directory="/etc/kubernetes"
pki_directory="/etc/kubernetes/pki"  # Duplicated above.
service_cluster_ip_range="10.96.0.0/12"  # Duplicated above.

# Kubernetes Controller Manager

cat > kube-controller-manager.service <<- EOF
	[Unit]
	Description=Kubernetes Controller Manager
	Documentation=https://github.com/kubernetes/kubernetes
	
	[Service]
	ExecStart=/usr/local/bin/kube-controller-manager \\
	  --bind-address=0.0.0.0 \\
	  --client-ca-file=${pki_directory}/ca.crt \\
	  --cluster-name=kubernetes \\
	  --cluster-signing-cert-file=${pki_directory}/ca.crt \\
	  --cluster-signing-key-file=${pki_directory}/ca.key \\
	  --kubeconfig=${config_directory}/controller-manager.conf \\
	  --leader-elect=true \\
	  --port=0 \\
	  --root-ca-file=${pki_directory}/ca.crt \\
	  --service-account-private-key-file=${pki_directory}/sa.key \\
	  --service-cluster-ip-range=${service_cluster_ip_range} \\
	  --use-service-account-credentials=true \\
	  --v=2
	Restart=on-failure
	RestartSec=5
	
	[Install]
	WantedBy=multi-user.target
EOF

# ---

# Kubernetes Scheduler Configuration Parameters

config_directory="/etc/kubernetes"  # Duplicated above.

# Kubernetes Scheduler

cat > scheduler.yaml <<- EOF
	apiVersion: kubescheduler.config.k8s.io/v1beta1
	kind: KubeSchedulerConfiguration
	clientConnection:
	  kubeconfig: "${config_directory}/scheduler.kubeconfig"
	leaderElection:
	  leaderElect: true
EOF

cat > kube-scheduler.service <<- EOF
	[Unit]
	Description=Kubernetes Scheduler
	Documentation=https://github.com/kubernetes/kubernetes
	
	[Service]
	ExecStart=/usr/local/bin/kube-scheduler \\
	  --config=${config_directory}/scheduler.yaml \\
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
		  - "10.96.0.10"
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
