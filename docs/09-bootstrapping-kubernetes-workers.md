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

## Provisioning a Kubernetes Worker Node

### Download and Install the Kubernetes Worker Node Binaries

Since `curl` is not available on the base Debian image, grab the necessary files using your laptop,

```
(
  export KUBE_VERSION="1.22.2"
  curl -O -L "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/arm64/kubelet"
  curl -O -L "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/arm64/kube-proxy"
  curl -O -L "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/linux/arm64/kubectl"
)
```

Set the permissions to enable the execute bit and then copy them to each controller instance,

```
chmod +x kubelet kube-proxy kubectl

for host in node-0 node-1 node-2; do
  scp kubelet kube-proxy kubectl root@$host:/usr/local/bin
done
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

Certificates are kept in `/etc/kubernetes/pki`, kubeconfig files are kept in `/etc/kubernetes` and the service configuration will be kept in `/var/lib/kubelet`.

When copying the certificate files, the filenames will be changed to reflect the state of the system as it would be when using `kubeadm`.

```
# Setup the directories.
sudo mkdir -p /etc/kubernetes/pki
sudo mkdir -p /var/lib/kubelet
```

```
# Distribute the certificates.
sudo cp ca.pem /etc/kubernetes/pki/ca.crt
sudo cp "${HOSTNAME}.pem" "/etc/kubernetes/pki/${HOSTNAME}.crt"
sudo cp "${HOSTNAME}-key.pem" "/etc/kubernetes/pki/${HOSTNAME}.key"
```

```
# Distribute the Kubelet kubeconfig file.
sudo cp "${HOSTNAME}-kubelet.conf" /etc/kubernetes/kubelet.conf
```

```
# Distribute the Kubelet systemd unit file.
sudo cp kubelet.service /etc/systemd/system/kubelet.service
```

```
# Distribute the Kubelet service configuration file.
sudo cp "${HOSTNAME}-kubelet.yaml" /var/lib/kubelet/config.yaml
```

## Configure the Kubernetes Proxy

The service configuration will be kept in `/var/lib/kube-proxy`.

```
# Setup the directories.
sudo mkdir -p /var/lib/kube-proxy
```

```
# Distribute the Kube Proxy kubeconfig file.
sudo cp proxy.conf /etc/kubernetes/proxy.conf
```

```
# Distribute the Kube Proxy systemd unit file.
sudo cp kube-proxy.service /etc/systemd/system/kube-proxy.service
```

```
# Distribute the Kube Proxy service configuration file.
sudo cp proxy.yaml /var/lib/kube-proxy/config.yaml
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
