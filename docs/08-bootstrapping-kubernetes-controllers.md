# Bootstrapping the Kubernetes Control Plane

Since there is only a single controller host, this will be setup without high-availability. All traffic will go to the node directly.

The control plane consists of the following components:
- API Server
- Scheduler
- Controller Manager

Additionally, `kubectl` will be installed and configured to interact with the cluster.

## Generating the Kubernetes Control Plane Configuration

All configuration is generated using the script found here: 
https://github.com/nerditup/kubernetes/blob/main/scripts/generate-config.sh

Generate the configuration files and then copy them to each controller instance: `controller-0`. 

## Prerequisites

The following commands must be run on each controller instance: `controller-0`. Login to each controller instance using `ssh`.

### Download and Install the Kubernetes Control Plane Binaries

Download the official Kubernetes release binaries:

```
wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.21.1/bin/linux/arm64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.21.1/bin/linux/arm64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.21.1/bin/linux/arm64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.21.1/bin/linux/arm64/kubectl"
```

Install the Kubernetes binaries:

```
{
  chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
  sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
}
```

## Configure the API Server

All configuration and certificates will be kept in `/etc/kubernetes`.

```
# Setup the directories.
sudo mkdir -p /etc/kubernetes/pki

# Distribute the certificates.
sudo cp ca.pem /etc/kubernetes/pki/ca.crt
sudo cp ca-key.pem /etc/kubernetes/pki/ca.key
sudo cp kubernetes.pem /etc/kubernetes/pki/apiserver.crt
sudo cp kubernetes-key.pem /etc/kubernetes/pki/apiserver.key
sudo cp service-account.pem /etc/kubernetes/pki/sa.crt
sudo cp service-account-key.pem /etc/kubernetes/pki/sa.key

# Distribute the encryption configuration file.
sudo cp encryption-config.yaml /etc/kubernetes/encryption-config.yaml

# Distribute the API Server systemd unit file.
sudo cp kube-apiserver.service /etc/systemd/system/kube-apiserver.service
```

## Configure the Controller Manager

All configuration and certificates will be kept in `/etc/kubernetes`.

```
# Distribute the Controller Manager configuration file.
sudo cp controller-manager.conf /etc/kubernetes/controller-manager.conf

# Distribute the Controller Manager systemd unit file.
sudo cp kube-controller-manager.service /etc/systemd/system/kube-controller-manager.service
```

## Configure the Scheduler

All configuration and certificates will be kept in `/etc/kubernetes`.

```
# Distribute the Scheduler configuration file.
sudo cp scheduler.conf /etc/kubernetes/scheduler.conf
sudo cp scheduler.yaml /etc/kubernetes/scheduler.yaml

# Distribute the Scheduler systemd unit file.
sudo cp kube-scheduler.service /etc/systemd/system/kube-scheduler.service
```

## Start the Controller Services

```
{
  sudo systemctl daemon-reload
  sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
  sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler
}
```

Allow up to 10 seconds for the Kubernetes API Server to fully initialize.

### Verification

```
kubectl cluster-info --kubeconfig admin.conf
```

> Kubernetes control plane is running at https://127.0.0.1:6443


## Configure RBAC for Kubelet Authorization

This only needs to be run once on a single controller node (in this case there is only `controller-0`).

```
cat <<- EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
	apiVersion: rbac.authorization.k8s.io/v1
	kind: ClusterRole
	metadata:
	  annotations:
	    rbac.authorization.kubernetes.io/autoupdate: "true"
	  labels:
	    kubernetes.io/bootstrapping: rbac-defaults
	  name: system:kube-apiserver-to-kubelet
	rules:
	  - apiGroups:
	      - ""
	    resources:
	      - nodes/proxy
	      - nodes/stats
	      - nodes/log
	      - nodes/spec
	      - nodes/metrics
	    verbs:
	      - "*"
EOF
```

```
cat <<- EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
	apiVersion: rbac.authorization.k8s.io/v1
	kind: ClusterRoleBinding
	metadata:
	  name: system:kube-apiserver
	  namespace: ""
	roleRef:
	  apiGroup: rbac.authorization.k8s.io
	  kind: ClusterRole
	  name: system:kube-apiserver-to-kubelet
	subjects:
	  - apiGroup: rbac.authorization.k8s.io
	    kind: User
	    name: kubernetes
EOF
```

Next: [Bootstrapping the Kubernetes Worker Nodes](09-bootstrapping-kubernetes-workers.md)
