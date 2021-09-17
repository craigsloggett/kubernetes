# Bootstrapping the Kubernetes Worker Nodes

The worker nodes consist of the following components:
- The Container Runtime
- Kubelet
- Kube Proxy

Additionally, `kubectl` will be installed and configured to interact with the cluster.

## Generating the Kubernetes Worker Nodes Configuration

All configuration is generated using the script found here: 
https://github.com/nerditup/kubernetes/blob/main/scripts/generate-config.sh

Generate the configuration files and then copy them to each worker node instance: `node-0`, `node-1` and `node-2`. 

## Prerequisites

The following commands must be run on each worker node instance: `node-0`, `node-1` and `node-2`. Login to each controller instance using `ssh`.

## Install the Container Runtime

**NOTE:** This might move to `03-compute-resources.md` if the Networking Plugin requires running a container on the controller node.

> If you are running Kubernetes Apiserver outside of your cluster for some reason (like keeping master nodes behind a firewall), make sure that you run Cilium on master nodes too.

Looks like we need to add Kubelet to the controller nodes too!

### Install `curl` and `gnupg`

```
apt install curl gnupg
```

### Install `apt-transport-https` and `ca-certificates`

```
apt install apt-transport-https ca-certificates
```

### Add openSUSE's OBS Repository to APT

There are a few repositories to add for `cri-o` and the dependencies.

```
# Run the following commands as root.

export VERSION=1.21
export OS=Debian_Testing

echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list

curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/Release.key | apt-key add -
```

Since cri-o for arm64 is not published to the Debian_Testing repository, xUbuntu_20.04 is used instead,

```
# Run the following commands as root.

export OS=xUbuntu_20.04

echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$VERSION/$OS/ /" > /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.list

curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/Release.key | apt-key add -
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/Release.key | apt-key add -
```

Update the repositories,

```
apt update
apt upgrade
```

### Install the Container Runtime

The `runc` packaged with `cri-o` is used to ensure compatibility between versions.

```
apt install cri-o cri-o-runc
```

## Provisioning a Kubernetes Worker Node

### Download and Install the Kubernetes Worker Node Binaries

Download the official Kubernetes release binaries:

```
wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.21.1/bin/linux/arm64/kubelet" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.21.1/bin/linux/arm64/kube-proxy" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.21.1/bin/linux/arm64/kubectl"
```

Install the Kubernetes binaries:

```
{
  chmod +x kubelet kube-proxy kubectl
  sudo mv kubelet kube-proxy kubectl /usr/local/bin/
}
```

### Configure CNI Networking

Create the `bridge` network configuration file:

```
cat <<EOF | sudo tee /etc/cni/net.d/100-crio-bridge.conf
{
    "cniVersion": "0.3.1",
    "name": "crio",
    "type": "bridge",
    "bridge": "cni0",
    "isGateway": true,
    "ipMasq": true,
    "hairpinMode": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{ "subnet": "10.85.0.0/16" }],
          [{ "subnet": "1100:200::/24" }]
        ],
        "routes": [
          { "dst": "0.0.0.0/0" },
          { "dst": "1100:200::1/24" }
        ]
    }
}
EOF
```

Create the `loopback` network configuration file:

```
cat <<EOF | sudo tee /etc/cni/net.d/200-loopback.conf
{
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF
```

## Configure the Kubelet

All configuration and certificates will be kept in `/etc/kubernetes`.

```
# Setup the directories.
sudo mkdir -p /etc/kubernetes/pki

# Distribute the certificates.
sudo cp ca.pem /etc/kubernetes/pki/ca.crt
sudo cp hostname.pem /etc/kubernetes/pki/hostname.crt
sudo cp hostname-key.pem /etc/kubernetes/pki/hostname.key

# Distribute the Kubelet configuration file.
sudo cp kubelet-config.yaml /etc/kubernetes/kubelet-config.yaml

# Distribute the Kubelet systemd unit file.
sudo cp kubelet.service /etc/systemd/system/kubelet.service
```

## Configure the Kubernetes Proxy

All configuration and certificates will be kept in `/etc/kubernetes`.

```
# Setup the directories.
sudo mkdir -p /etc/kubernetes

# Distribute the Kube Proxy configuration file.
sudo cp kube-proxy-config.yaml /etc/kubernetes/kube-proxy-config.yaml

# Distribute the Kube Proxy systemd unit file.
sudo cp kube-proxy.service /etc/systemd/system/kube-proxy.service
```

## Start the Worker Services

```
{
  sudo systemctl daemon-reload
  sudo systemctl enable kubelet kube-proxy
  sudo systemctl start kubelet kube-proxy
}
```

> Remember to run the above commands on each worker node: `worker-0`, `worker-1`, and `worker-2`.

## Verification

From `controller-0`, run the following command,

```
kubectl get nodes --kubeconfig admin.kubeconfig
```

> output

```
NAME       STATUS   ROLES    AGE   VERSION
node-0     Ready    <none>   22s   v1.21.0
node-1     Ready    <none>   22s   v1.21.0
node-2     Ready    <none>   22s   v1.21.0
```

Next: [Configuring kubectl for Remote Access](10-configuring-kubectl.md)
