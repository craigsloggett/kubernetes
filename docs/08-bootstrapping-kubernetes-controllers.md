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

## Configuration Distribution

Distribute the `kube-apiserver`, `kube-scheduler` and `kube-controller-manager` configuration files to each controller host:

```
for host in controller-0; do
  ssh nerditup@${host} 'mkdir -p ~/kubernetes/control-plane'
  scp kube-apiserver.service kube-controller-manager.service kube-scheduler.service scheduler.yaml nerditup@${host}:~/kubernetes/control-plane
done
```

## Download and Install the Kubernetes Control Plane Binaries

Since `curl` is not available on the base Debian image, grab the necessary files using your laptop,

```
(
  export KUBE_VERSION="1.22.2"
  curl -O -L "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/arm64/kube-apiserver"
  curl -O -L "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/arm64/kube-controller-manager"
  curl -O -L "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/arm64/kube-scheduler"
  curl -O -L "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/arm64/kubectl"
)
```

Set the permissions to enable the execute bit and then copy them to each controller instance,

```
chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl

for host in controller-0; do
  scp kube-apiserver kube-controller-manager kube-scheduler kubectl root@$host:/usr/local/bin
done
```

## Configure the API Server

The following commands must be run on each controller instance: `controller-0`. Login to each controller instance using `ssh`.

All certificates will be kept in `/etc/kubernetes/pki` and the configuration will be kept in `/var/lib/kube-apiserver`.

When copying the certificate files, the filenames will be changed to reflect the state of the system as it would be when using `kubeadm`.

```
# Setup the directories.
sudo mkdir -p /etc/kubernetes/pki
sudo mkdir -p /var/lib/kube-apiserver
```

```
# Distribute the certificates.
sudo cp ca.pem /etc/kubernetes/pki/ca.crt
sudo cp ca-key.pem /etc/kubernetes/pki/ca.key
sudo cp kubernetes.pem /etc/kubernetes/pki/apiserver.crt
sudo cp kubernetes-key.pem /etc/kubernetes/pki/apiserver.key
sudo cp sa.pem /etc/kubernetes/pki/sa.crt
sudo cp sa-key.pem /etc/kubernetes/pki/sa.key
```

```
# Distribute the encryption configuration file.
sudo cp encryption-config.yaml /var/lib/kube-apiserver/encryption-config.yaml
```

```
# Distribute the API Server systemd unit file.
sudo cp kube-apiserver.service /etc/systemd/system/kube-apiserver.service
```

## Configure the Controller Manager

All configuration and certificates will be kept in `/etc/kubernetes`.

```
# Distribute the Controller Manager kubeconfig file.
sudo cp controller-manager.conf /etc/kubernetes/controller-manager.conf
```

```
# Distribute the Controller Manager systemd unit file.
sudo cp kube-controller-manager.service /etc/systemd/system/kube-controller-manager.service
```

## Configure the Scheduler

All configuration and certificates will be kept in `/etc/kubernetes`.

```
# Setup the directories.
sudo mkdir -p /var/lib/kube-scheduler
```

```
# Distribute the Scheduler kubeconfig file.
sudo cp scheduler.conf /etc/kubernetes/scheduler.conf
```

```
# Distribute the Scheduler systemd unit file.
sudo cp kube-scheduler.service /etc/systemd/system/kube-scheduler.service
```

```
# Distribute the Scheduler service configuration file.
sudo cp scheduler.yaml /var/lib/kube-scheduler/config.yaml
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
cat <<- EOF | kubectl apply --kubeconfig admin.conf -f -
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
cat <<- EOF | kubectl apply --kubeconfig admin.conf -f -
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
