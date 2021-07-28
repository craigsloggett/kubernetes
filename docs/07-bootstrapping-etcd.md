# Bootstrapping the etcd Cluster

Kubernetes components are stateless and store cluster state in [etcd](https://github.com/etcd-io/etcd).

## Genertaing `etcd` Configuration

All configuration is generated using the script found here: 
https://github.com/nerditup/kubernetes/blob/main/scripts/generate-etcd-config.sh

Generate the configuration files and then copy them to each controller instance: `controller-0`. 

## Prerequisites

The following commands must be run on each controller instance: `controller-0`. Login to each controller instance using `ssh`.

## Bootstrapping an etcd Cluster Member

### Download and Install the etcd Binaries

```
wget "https://github.com/etcd-io/etcd/releases/download/v3.4.13/etcd-v3.4.13-linux-arm64.tar.gz"
tar -xzvf etcd-v3.4.13-linux-arm64.tar.gz
sudo mv etcd-v3.4.13-linux-arm64/etcd* /usr/local/bin
```

### Configure the etcd Server

Copy the configuration files to the appropriate directories.

```
# etcd Configuration File
sudo mkdir -p /etc/etcd/
sudo mv etcd-conf.yaml /etc/etcd/
sudo chown -R root:root /etc/etcd/

# systemd Service File
sudo mv etcd.service /etc/systemd/system/
sudo chown root:root /etc/systemd/system/etcd.service
```

All certificates will be kept in `/etc/kubernetes/pki/etcd`. The data directory for `etcd` will be `/var/lib/etcd`.

```
# Setup the directories.
sudo mkdir -p /etc/kubernetes/pki/etcd /var/lib/etcd
sudo chmod 700 /var/lib/etcd

# Distribute the certificates.
sudo cp ca.pem /etc/kubernetes/pki/etcd/ca.crt
sudo cp kubernetes.pem /etc/kubernetes/pki/etcd/server.crt
sudo cp kubernetes.pem /etc/kubernetes/pki/etcd/peer.crt
sudo cp kubernetes-key.pem /etc/kubernetes/pki/etcd/server.key
sudo cp kubernetes-key.pem /etc/kubernetes/pki/etcd/peer.key
```

### Enable and start the `etcd` service.

```
sudo systemctl daemon-reload
sudo systemctl enable etcd.service
sudo systemctl start etcd.service
```

### Verify

```
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://192.168.1.110:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

Next: [Bootstrapping the Kubernetes Control Plane](08-bootstrapping-kubernetes-controllers.md)
