# Kubernetes Raspberry Pi Cluster Setup (The Hard Way)

This guide will setup a Kubernetes cluster "the hard way" on a Raspberry Pi 4 cluster using four
physical machines. I have chosen not to use `kubeadm` in order to understand fully the deployment 
process of a Kubernetes cluster deployed on-premise.

Here are the software choices for this configuration:
 - Debian 11 Bullseye
 - Kubernetes
   - CRI-O
   - runc
   - kubenet

RBAC is used as the Authorization Mode in order to implement the principle of least privilege.

The "testing" release of Debian has been chosen for it's support of cgroups v2 with a `systemd`
version 244 or later. Older `systemd` versions do not support delegation of the `cpuset` controller.
`systemd` version `247.3-3` is marked for release in Debian 11. The use of cgroups v2 is important
since it supports imposing resource limitations on rootless containers.

`kubenet` has been chosen as the network provider to simplify the configuration required to get a 
bare metal MVP cluster. Using this guide, I plan on automating this process with POSIX shell scripts
to keep the dependencies as small as possible.

In the future, I would like to swap `kubenet` for `flannel` and then ultimately `calico` with eBGP 
and network policies configured with the goal of provisioning a "production ready" cluster following
the latest best practices.

My local machine is a MacBook.

## Versions

 - Debian: `11 (Testing)`
 - iptables: `1.8.7 (nf_tables)`
 - Kubernetes: `1.21.0`
 - CFSSL: `1.5.0`
 - etcd: `3.4.15`
 - cni: `0.9.1`
 - runc: `1.0.0-rc93`
 - cri-o: 
 - conmon: `2.0.27`

## Network CIDRs

 - Host CIDR: `192.168.1.0/16`
 - Cluster CIDR: `10.200.0.0/16`
 - Service Cluster CIDR: `10.32.0.0/16`

--- 

## Preparing the Hardware

1. Download a Debian SD card image for the Raspberry Pi: https://raspi.debian.net/tested-images/
2. Prepare the SD cards for each Raspberry Pi.

   a. Flash the image to each SD card:

   ```
   xzcat 20210210_raspi_4_bullseye.img.xz | sudo dd of=/dev/disk2 bs=64k
   ```
   
   b. Update the configuration settings of the image:
   
   ```
   vim /Volumes/RASPIFIRM/sysconf.txt
   # Uncomment and update the root_autherized_key value (e.g. pbcopy < ~/.ssh/id_ed25519.pub).
   # Uncomment and update the hostname value (e.g. k8s-controller-0).
   ```
   
   c. Unmount the SD card:

   ```
   sudo diskutil unmount /Volumes/RASPIFIRM
   ``` 

   d. Repeat for all four Raspberry Pis:
   
   ```
   controller-0
   node-0
   node-1
   node-2
   ```
### Preparing the OS

1. Update the OS:

```
apt update
apt upgrade
```

2. Check dmesg for errors.

   a. Add the regulatory database for wireless adapters:
   
   ```
   # Local machine
   git clone https://kernel.googlesource.com/pub/scm/linux/kernel/git/sforshee/wireless-regdb
   cd wireless-regdb
   git checkout <latest-release-tag>  # e.g. master-2020-11-20
   
   for host in controller-0 node-0 node-1 node-2
     do scp regulatory.db regulatory.db.p7s root@$host:/root
   done
   
   # Raspberry Pis
   
   mv /root/regulatory.db* /lib/firmware/
   reboot
   ```

   b. Install the Bluetooth firmware:
   
   ```
   firmware_repo_url="https://github.com/armbian/firmware/raw/master"
   wget -O /lib/firmware/brcm/BCM4345C5.hcd "${firmware_repo_url}"/brcm/BCM4345C5.hcd
   wget -O /lib/firmware/brcm/BCM4345C0.hcd "${firmware_repo_url}"/BCM4345C0.hcd
   wget -O /lib/firmware/brcm/brcmfmac43455-sdio.clm_blob "${firmware_repo_url}"/brcm/brcmfmac43455-sdio.clm_blob
   ```

3. Configure a regular user.

   a. Add the user.

   ```
   adduser nerditup
   usermod –a –G sudo nerditup
   ```
   
   b. Generate an SSH key.

   ```
   # As the regular user.
   ssh-keygen -t ed25519
   
   # As root.
   cp ~/.ssh/authorized_keys /home/nerditup/.ssh
   chown nerditup:nerditup /home/nerditup/.ssh/authorized_keys
   ```

   c. Install `sudo`.

   ```
   # As root.
   apt install sudo
   ```
   
   d. Login as the regular user.

4. Update `/etc/hosts`.

   a. Update the hostname:
   
   ```
   # Example entries to update.
   127.0.0.1       k8s-controller-0.localdomain k8s-controller-0
   ::1             k8s-controller-0.localdomain k8s-controller-0 ip6-localhost ip6-loopback
   ```
   
   b. Add the cluster IPs:
   
   ```
   # Kubernetes Cluster
   192.168.1.110   k8s-controller-0
   192.168.1.120   k8s-node-0
   192.168.1.121   k8s-node-1
   192.168.1.122   k8s-node-2
   ```

5. Copy SSH keys to each host:

```
# Example loop for k8s-controller-0.
for i in node-0 node-1 node-2; do ssh-copy-id nerditup@k8s-$i; done
```

6. Disable `swap`.

By default, the Debian image used for the Raspberry Pis doesn't use swap. To confirm,

```
cat /proc/swaps
```

** TBD **
7. Enable cgroups.

By default, the Debian image used for the Raspberry Pis has all required cgroups enabled. To 
confirm,

```
cat /proc/cgroups | column -t
```

** TBD **
8. Enable `overlay` and `br_netfilter` kernel modules.

On all machines:

```
vi /etc/modules-load.d/modules.conf

# Add the following to this file.

overlay
br_netfilter
```

** TBD **
9. Enable ip forwarding.

On all machines:

```
vi /etc/sysctl.d/local.conf

# Add the following to this file.

net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
```

10. Reboot all machines.

---

## Install the Client Tools (Locally)

The following is to be run on a local machine.

```
export KUBE_VERSION=1.21.0
export CFSSL_VERSION=1.5.0
```

### kubectl

```
curl -o kubectl "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/darwin/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl ~/.local/bin
```

### cfssl

```
curl -o cfssl -L "https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssl_${CFSSL_VERSION}_darwin_amd64"
curl -o cfssljson -L "https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssljson_${CFSSL_VERSION}_darwin_amd64"
chmod +x cfssl cfssljson
sudo mv cfssl cfssljson ~/.local/bin
```

---

## Provisioning CA and Generating TLS Certs

The following is to be run on a local machine.

### Authentication

For Kubernetes certificates best practices, reference this document:
https://kubernetes.io/docs/setup/best-practices/certificates/

For details on how Kubernetes authenticates using signed certificates, reference this document:
https://kubernetes.io/docs/reference/access-authn-authz/authentication/

> Kubernetes determines the username from the common name field in the 'subject' of the cert (e.g., "/CN=bob").

Client certificates will be generated to authenticate API requests for each of the following roles:
 - admin
 - system:kube-controller-manager
 - system:kube-proxy
 - system:kube-scheduler

Additionally, a service account client certificate will be generated to authenticate service account
API requests.

### Authorization

For details on security best practices, refer to this document:
https://kubernetes.io/docs/tasks/administer-cluster/securing-a-cluster/

> It is recommended that you use the Node and RBAC authorizers together, in combination with the NodeRestriction admission plugin.

For details on node authorization, refer to this document:
https://kubernetes.io/docs/reference/access-authn-authz/node/

> In order to be authorized by the Node authorizer, kubelets must use a credential that identifies them as being in the `system:nodes` group, with a username of `system:node:<nodeName>`.

When generating the kubelet client certificates, the CN must be `system:node:<nodeName>` where 
`<nodeName>` will be the hostname of the node the certificate is being generated for.

### Genertaing TLS Certs

All certificates are generated using the script found here: 
https://github.com/nerditup/kubernetes/blob/main/certs/generate-ca.sh

#### Verify

```
openssl x509 -in <certificate_name.pem> -text -noout
```

### Distribute the TLS Certificates

Distribute the appropriate certificates and private keys to each node host:

```
for host in node-0 node-1 node-2; do
  scp ca.pem "${host}"-key.pem "${host}".pem nerditup@${host}:~
done
```

Distribute the appropriate certificates and private keys to each controller host:

```
for host in controller-0; do
  scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem nerditup@${host}:~
done
```

---

## Provisioning Kubernetes Configuration Files for Authentication

The following is to be run on a local machine.

### Genertaing Kubernetes Configuration Files

All kubeconfig files are generated using the script found here: 
https://github.com/nerditup/kubernetes/blob/main/certs/generate-kubeconfig.sh

### Distribute the Kubernetes Configuration Files

Distribute the `kubelet` and `kube-proxy` kubeconfig files to each node host:

```
for host in node-0 node-1 node-2; do
  scp ${host}.kubeconfig kube-proxy.kubeconfig nerditup@${host}:~
done
```

Distribute the `admin`, `kube-controller-manager` and `kube-scheduler` kubeconfig files to each 
controller host:

```
for host in controller-0; do
  scp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig nerditup@${host}:~
done
```

---

## Generating the Data Encryption Config and Key

Generate the encryption key used to encrypt cluster data at rest.

```
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
```

```
cat > encryption-config.yaml << EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
```

Distribute the `encryption-config` file to each controller host:

```
for host in controller-0; do
  scp encryption-config.yaml nerditup@${host}:~
done
```

---

## Bootstrapping the etcd Cluster

The following is to be run on the controller nodes.

```
wget "https://github.com/etcd-io/etcd/releases/download/v3.4.15/etcd-v3.4.15-linux-arm64.tar"
tar -xvf etcd-v3.4.15-linux-arm64.tar
sudo mv etcd-v3.4.15-linux-arm64/etcd* /usr/local/bin
```

All certificates will be kept in `/etc/etcd/tls`.

```
sudo mkdir -p /etc/etcd/tls /var/lib/etcd
sudo chmod 700 /var/lib/etcd
sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/tls
```

### Generate the `etcd` configuration file.

```
controller_hostname="controller-0"
controller_ip="192.168.1.110"
etcd_pki_directory="/etc/etcd/tls"

cat > etcd-conf.yaml <<- EOF
	# This is the configuration file for the etcd server.
	
	# Human-readable name for this member.
	name: '${controller_hostname}'
	
	# Path to the data directory.
	data-dir: '/var/lib/etcd'
	
	# Path to the dedicated wal directory.
	wal-dir:
	
	# Number of committed transactions to trigger a snapshot to disk.
	snapshot-count: 10000
	
	# Time (in milliseconds) of a heartbeat interval.
	heartbeat-interval: 100
	
	# Time (in milliseconds) for an election to timeout.
	election-timeout: 1000
	
	# Raise alarms when backend size exceeds the given quota. 0 means use the
	# default quota.
	quota-backend-bytes: 0
	
	# List of comma separated URLs to listen on for peer traffic.
	listen-peer-urls: 'https://${controller_ip}:2380'
	
	# List of comma separated URLs to listen on for client traffic.
	listen-client-urls: 'https://${controller_ip}:2379,https://127.0.0.1:2379'
	
	# Maximum number of snapshot files to retain (0 is unlimited).
	max-snapshots: 5
	
	# Maximum number of wal files to retain (0 is unlimited).
	max-wals: 5
	
	# Comma-separated white list of origins for CORS (cross-origin resource sharing).
	cors:
	
	# List of this member's peer URLs to advertise to the rest of the cluster.
	# The URLs needed to be a comma-separated list.
	initial-advertise-peer-urls: 'https://${controller_ip}:2380'
	
	# List of this member's client URLs to advertise to the public.
	# The URLs needed to be a comma-separated list.
	advertise-client-urls: 'https://${controller_ip}:2379'
	
	# Discovery URL used to bootstrap the cluster.
	discovery:
	
	# Valid values include 'exit', 'proxy'
	discovery-fallback: 'proxy'
	
	# HTTP proxy to use for traffic to discovery service.
	discovery-proxy:
	
	# DNS domain used to bootstrap initial cluster.
	discovery-srv:
	
	# Initial cluster configuration for bootstrapping.
	initial-cluster: '${controller_hostname}=https://${controller_ip}:2380'
	
	# Initial cluster token for the etcd cluster during bootstrap.
	initial-cluster-token: 'etcd-cluster'
	
	# Initial cluster state ('new' or 'existing').
	initial-cluster-state: 'new'
	
	# Reject reconfiguration requests that would cause quorum loss.
	strict-reconfig-check: false
	
	# Accept etcd V2 client requests
	enable-v2: true
	
	# Enable runtime profiling data via HTTP server
	enable-pprof: true
	
	# Valid values include 'on', 'readonly', 'off'
	proxy: 'off'
	
	# Time (in milliseconds) an endpoint will be held in a failed state.
	proxy-failure-wait: 5000
	
	# Time (in milliseconds) of the endpoints refresh interval.
	proxy-refresh-interval: 30000
	
	# Time (in milliseconds) for a dial to timeout.
	proxy-dial-timeout: 1000
	
	# Time (in milliseconds) for a write to timeout.
	proxy-write-timeout: 5000
	
	# Time (in milliseconds) for a read to timeout.
	proxy-read-timeout: 0
	
	client-transport-security:
	  # Path to the client server TLS cert file.
	  cert-file: '/etc/etcd/tls/kubernetes.pem'
	
	  # Path to the client server TLS key file.
	  key-file: '/etc/etcd/tls/kubernetes-key.pem'
	
	  # Enable client cert authentication.
	  client-cert-auth: true
	
	  # Path to the client server TLS trusted CA cert file.
	  trusted-ca-file: '/etc/etcd/tls/ca.pem'
	
	  # Client TLS using generated certificates
	  auto-tls: false
	
	peer-transport-security:
	  # Path to the peer server TLS cert file.
	  cert-file: '/etc/etcd/tls/kubernetes.pem'
	
	  # Path to the peer server TLS key file.
	  key-file: '/etc/etcd/tls/kubernetes-key.pem'
	
	  # Enable peer client cert authentication.
	  client-cert-auth: true
	
	  # Path to the peer server TLS trusted CA cert file.
	  trusted-ca-file: '/etc/etcd/tls/ca.pem'
	
	  # Peer TLS using generated certificates.
	  auto-tls: false
	
	# Enable debug-level logging for etcd.
	log-level: 'info'
	
	logger: 'zap'
	
	# Specify 'stdout' or 'stderr' to skip journald logging even when running under systemd.
	log-outputs: [stderr]
	
	# Force to create a new one member cluster.
	force-new-cluster: false
	
	auto-compaction-mode: periodic
	auto-compaction-retention: '1'
EOF
```

```
sudo mv etcd-conf.yaml /etc/etcd/
sudo chown -R root:root /etc/etcd/
```

### Generate the `etcd` system unit file.

```
cat > etcd.service <<- EOF
	[Unit]
	Description=etcd
	Documentation=https://github.com/coreos
	
	[Service]
	Environment="ETCD_UNSUPPORTED_ARCH=arm64"
	Type=notify
	ExecStart=/usr/local/bin/etcd \\
	  --config-file /etc/etcd/etcd-conf.yaml
	Restart=on-failure
	RestartSec=5
	
	[Install]
	WantedBy=multi-user.target
EOF
```

```
sudo mv etcd.service /etc/systemd/system/
sudo chown root:root /etc/systemd/system/etcd.service
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
  --endpoints=https://127.0.0.1:2379 \
  --cacert=${etcd_pki_directory}/ca.pem \
  --cert=${etcd_pki_directory}/kubernetes.pem \
  --key=${etcd_pki_directory}/kubernetes-key.pem
```

---

## Bootstrapping the Kubernetes Control Plane

### Provision the Kubernetes Control Plane

All service and kubeconfig files are generated using the script found here: 
https://github.com/nerditup/kubernetes/blob/main/config/generate-config.sh

#### Distribute the Configuration Files

```
for host in controller-0; do
  scp kube-apiserver.service kube-controller-manager.service \
    kube-scheduler.service kube-scheduler.yaml nerditup@${host}:~
done
```

#### Download and Install the Kubernetes Controller Binaries

```
kubernetes_version="1.21.0"
kubernetes_releases_url="https://storage.googleapis.com/kubernetes-release/release"

for bin in kube-apiserver kube-controller-manager kube-scheduler kubectl; do
  wget "${kubernetes_releases_url}/v${kubernetes_version}/bin/linux/arm64/${bin}"
  chmod +x "${bin}"
  sudo mv "${bin}" /usr/local/bin/
  sudo chown root:root /usr/local/bin/"${bin}"
done
```

#### Prepare the Configuration Directory

```
sudo mkdir -p /etc/kubernetes/kubeconfig
sudo mkdir -p /etc/kubernetes/pki
```

#### Configure the Kubernetes API Server

Copy the TLS certificates and encryption configuration to `/etc/kubernetes/pki`.

```
sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
  service-account-key.pem service-account.pem \
  /etc/kubernetes/pki/
```

```
sudo mv encryption-config.yaml /etc/kubernetes/
```

```
sudo mv kube-apiserver.service /etc/systemd/system/
```

#### Configure the Kubernetes Controller Manager

Move the `kube-controller-manager` kubeconfig to `/etc/kubernetes/kubeconfig`.

```
sudo mv kube-controller-manager.kubeconfig /etc/kubernetes/kubeconfig
```

```
sudo mv kube-controller-manager.service /etc/systemd/system/
```

#### Configure the Kubernetes Scheduler

Move the `kube-scheduler` kubeconfig to `/etc/kubernetes/kubeconfig`.

```
sudo mv kube-scheduler.kubeconfig /etc/kubernetes/kubeconfig
```

```
sudo mv kube-scheduler.yaml /etc/kubernetes/
```

```
sudo mv kube-scheduler.service /etc/systemd/system/
```

#### Update Ownership on Configuration Files

```
sudo chown -R root:root /etc/kubernetes
sudo chown -R root:root /etc/systemd/system
```

#### Start the Services

```
sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler
```

### Setup RBAC for Kubelet Authorization

This only needs to be run once on a single controller node (in this case there is 
only `controller-0`).

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

---

## Bootstrapping the Kubernetes Worker Nodes

### Install the OS Dependencies

```
sudo apt update
sudo apt install socat conntrack ipset
```

### Download and Install the Kubernetes Worker Nodes Binaries

```
kubernetes_version="1.21.0"
kubernetes_releases_url="https://storage.googleapis.com/kubernetes-release/release"

for bin in kube-proxy kubelet kubectl; do
  wget "${kubernetes_releases_url}/v${kubernetes_version}/bin/linux/arm64/${bin}"
  chmod +x "${bin}"
  sudo mv "${bin}" /usr/local/bin/
  sudo chown root:root /usr/local/bin/"${bin}"
done
```

#### Prepare the Configuration Directory

```
sudo mkdir -p /etc/kubernetes/kubeconfig
sudo mkdir -p /etc/kubernetes/pki
sudo mkdir -p /var/run/kubernetes
```

Copy the TLS certificates configuration to `/etc/kubernetes/pki`.

```
sudo mv ca.pem node-*.pem /etc/kubernetes/pki/
```

Copy the Kubernetes configuration to `/etc/kubernetes/kubeconfig`.

```
sudo mv *.kubeconfig /etc/kubernetes/kubeconfig/
```

#### Update Ownership on Configuration Files

```
sudo chown -R root:root /etc/kubernetes/
```

### Download and Install the Container Runtime

#### CRI-O

> CRI-O follows the Kubernetes release cycles with respect to its minor versions (1.x.0).
> Patch releases (1.x.y) for CRI-O are not in sync with those from Kubernetes, because those are 
> scheduled for each month, whereas CRI-O provides them only if necessary.

Note: I'm currently using a build artifact directly until the next release since there were
      previously no arm64 binaries being built.

      See the following PR for details: https://github.com/cri-o/cri-o/pull/4718

```
crio_version="1.21.0-dev"
crio_releases_url="https://github.com/cri-o/cri-o/actions/runs/733139722"
# This needs to be authenticated in order to download, I ended up copying locally.
```

```
tar xvzf cri-o.arm64.da81fd7d70110be3636a6913fce5de0c9a9731e6.tar.gz
cri-o/./install
```

#### runc

Since the `runc` repository doesn't offer `arm64` binary releases, I have captured the
binary from Docker's `containerd.io` project and placed it in this repository under `/bin`.

From the local machine, copy this binary to each node.

```
for host in node-0 node-1 node-2; do
  scp bin/runc-arm64 nerditup@${host}:~
done
```

On each node machine, place the `runc` binary in the system path.

```
sudo mv runc-arm64 /usr/local/bin/runc
sudo chown root:root /usr/local/bin/runc
```

### Download and Install the Container Networking Plugins

```
cni_version="0.9.1"
cni_releases_url="https://github.com/containernetworking/plugins/releases/download"
wget "${cni_releases_url}"/v${cni_version}/cni-plugins-linux-arm64-v${cni_version}.tgz
```

```
sudo mkdir -p /etc/cni/net.d
sudo mkdir -p /opt/cni/bin
```

```
sudo tar -xvf cni-plugins-linux-arm64-v0.9.1.tgz -C /opt/cni/bin/
```

---
# WIP from here on...

Overall steps:

1. Do K8s the Hard Way
2. Don't deploy DNS
3. Configure kubenet
4. Deploy DNS

Project Calico will be used as the Network Plugin to manage Pod networking and Network Policies.
 - BGP dataplane ?
 - Standard Linux dataplane ?
 - Ethernet fabric
 - Kubernetes API datastore (kdd)
 - Disable IP-in-IP encapsulation.
 - Enable etcd TLS (/etc/etcd/).
 - Configure IP Pools.
 - USE_POD_CIDR = true

Install the Calico binary (CNI plugin) on every node in the Kubernetes cluster.

The CNI plugin must authenticate with the K8s API server. Generate a certificate and sign it, then
create the kubeconfig.

Define the cluster role that the Calico CNI plugin will use, then bind it to the account.


### Reference here for k8s config file apiVersions: https://github.com/kubernetes/kubernetes/tree/master/staging/src/k8s.io

# just run on one of the controller nodes (k8s-master-1)





# on all the workers at the same time (k8s-node-1 k8s-node-2 k8s-node-3)

apt install socat conntrack ipset

swapoff -a

systemctl enable systemd-resolved.service
systemctl start systemd-resolved.service

cp /usr/lib/systemd/network/99-default.link /etc/systemd/network/

# update with MACAddressPolicy=none


# containerd and runc aren't available for arm64
# docker hosts containerd builds for arm64!!
# runc is included in the containerd deb file provided by Docker :) 

wget https://download.docker.com/linux/debian/dists/buster/pool/stable/arm64/containerd.io_1.4.4-1_arm64.deb
dpkg -i containerd.io_1.4.4-1_arm64.deb

wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.20.0/crictl-v1.20.0-linux-arm64.tar.gz \
  https://github.com/containernetworking/plugins/releases/download/v0.9.1/cni-plugins-linux-arm64-v0.9.1.tgz \
  https://storage.googleapis.com/kubernetes-release/release/v1.20.4/bin/linux/arm64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.20.4/bin/linux/arm64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.20.4/bin/linux/arm64/kubelet

mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

{
  tar -xvf crictl-v1.20.0-linux-arm64.tar.gz
  tar -xvf cni-plugins-linux-arm64-v0.9.1.tgz -C /opt/cni/bin/
  chmod +x crictl kubectl kube-proxy kubelet 
  mv crictl kubectl kube-proxy kubelet /usr/local/bin/
}


# cniVersion refers to the CNI Spec version: https://www.cni.dev/docs/spec/
cat <<EOF | tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.4.0",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [
            {"subnet": "10.16.0.0/16"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

# Update /etc/cni/net.d/99-loopback.conf to cniVersion: 0.4.0


cat << EOF | tee /etc/containerd/config.toml
# Use config version 2 to enable new configuration fields.
# Config file is parsed as version 1 by default.
# Version 2 uses long plugin names, i.e. "io.containerd.grpc.v1.cri" vs "cri".
version = 2

# The 'plugins."io.containerd.grpc.v1.cri"' table contains all of the server options.
[plugins."io.containerd.grpc.v1.cri"]

  # 'plugins."io.containerd.grpc.v1.cri".containerd' contains config related to containerd
  [plugins."io.containerd.grpc.v1.cri".containerd]

    # snapshotter is the snapshotter used by containerd.
    snapshotter = "overlayfs"

    # default_runtime_name is the default runtime name to use.
    default_runtime_name = "runc"

    # 'plugins."io.containerd.grpc.v1.cri".containerd.runtimes' is a map from CRI RuntimeHandler strings, which specify types
    # of runtime configurations, to the matching configurations.
    # In this example, 'runc' is the RuntimeHandler string to match.
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]

      # runtime_type is the runtime type to use in containerd.
      # The default value is "io.containerd.runc.v2" since containerd 1.4.
      # The default value was "io.containerd.runc.v1" in containerd 1.3, "io.containerd.runtime.v1.linux" in prior releases.
      runtime_type = "io.containerd.runc.v2"

      # 'plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options' is options specific to
      # "io.containerd.runc.v1" and "io.containerd.runc.v2". Its corresponding options type is:
      #   https://github.com/containerd/containerd/blob/v1.3.2/runtime/v2/runc/options/oci.pb.go#L26 .
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]

        # SystemdCgroup enables systemd cgroups.
        SystemdCgroup = true
EOF

cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

cat <<EOF | tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStartPre=/sbin/modprobe br_netfilter
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF




{
  mv ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/
  mv ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
  mv ca.pem /var/lib/kubernetes/
}


cat <<EOF | tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
cgroupDriver: "systemd"
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
EOF


cat <<EOF | tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig



cat <<EOF | tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.16.0.0/16"
EOF



cat <<EOF | tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml \\
  --cleanup=true
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


# Add master, nodes to /etc/hosts on all machines.

systemctl daemon-reload
systemctl enable containerd kubelet kube-proxy
systemctl start containerd kubelet kube-proxy

# Check /var/log/syslog for errors

{
  kubectl config set-cluster k8s-pi-cluster \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://192.168.1.200:6443

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem

  kubectl config set-context k8s-pi-cluster \
    --cluster=k8s-pi-cluster \
    --user=admin

  kubectl config use-context k8s-pi-cluster
}


# Setup the L2 networking
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

# Setup the DNS Service
kubectl apply -f coredns-1.8.3.yaml
```
