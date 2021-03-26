# Kubernetes Raspberry Pi Cluster Setup (The Hard Way)

This guide will setup a Kubernetes cluster "the hard way" on a Raspberry Pi 4 cluster using four
physical machines. I have chosen not to use `kubeadm` in order to understand fully the deployment 
process of a Kubernetes cluster deployed on-premise.

Here are the software choices for this configuration:
 - Debian 10 Buster
 - Kubernetes
   - CRI-O
   - runc
   - kubenet

`kubenet` has been chosen as the network provider to simplify the configuration required to get a 
bare metal MVP cluster. Using this guide, I plan on automating this process with POSIX shell scripts
to keep the dependencies as small as possible.

In the future, I would like to swap `kubenet` for `flannel` and then ultimately `calico` with eBGP 
and network policies configured with the goal of provisioning a "production ready" cluster following
the latest best practices.

## Versions

 - Debian: `10.8`
 - iptables: `1.8.2 (nf_tables)`
 - Kubernetes: `1.20.5`
 - CFSSL: `1.5.0`
 - cri-o: 
 - runc: 

## Network CIDRs

 - Host CIDR: `192.168.1.0/16`
 - Cluster CIDR: `10.200.0.0/16`
 - Service Cluster CIDR: `10.32.0.0/16`

## Preparing the Hardware

1. Download a Debian SD card image for the Raspberry Pi: https://raspi.debian.net/tested-images/
2. Prepare the SD cards for each Raspberry Pi.

   a. Flash the image to each SD card:

   ```
   xzcat 20210210_raspi_4_buster.img.xz | sudo dd of=/dev/disk2 bs=64k
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
   k8s-controller-0
   k8s-node-0
   k8s-node-1
   k8s-node-2
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
   
   for i in controller-0 node-0 node-1 node-2
     do scp regulatory.db regulatory.db.p7s root@k8s-$i:/root
   done
   
   # Raspberry Pis
   
   mv /root/regulatory.db* /lib/firmware/
   reboot
   ```

   b. Install the Bluetooth firmware:
   
   ```
   wget -O /lib/firmware/brcm/BCM4345C5.hcd https://github.com/armbian/firmware/raw/master/brcm/BCM4345C5.hcd
   wget -O /lib/firmware/brcm/BCM4345C0.hcd https://github.com/armbian/firmware/raw/master/BCM4345C0.hcd
   wget -O /lib/firmware/brcm/brcmfmac43455-sdio.clm_blob https://github.com/armbian/firmware/raw/master/brcm/brcmfmac43455-sdio.clm_blob
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
   
   c. Login as the regular user.

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

7. Enable cgroups.

By default, the Debian image used for the Raspberry Pis has all required cgroups enabled. To 
confirm,

```
cat /proc/cgroups | column -t
```

8. Enable `overlay` and `br_netfilter` kernel modules.

On all machines:

```
vi /etc/modules-load.d/modules.conf

# Add the following to this file.

overlay
br_netfilter
```

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

## Install the Client Tools (Locally)

Everything here it to be done on a local machine (macOS is used here).

```
export KUBE_VERSION=1.20.5
export CFSSL_VERSION=1.5.0
```

### kubectl

```
curl -o kubectl "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/darwin/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin
```

### cfssl

```
curl -o cfssl -L "https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssl_${CFSSL_VERSION}_darwin_amd64"
curl -o cfssljson -L "https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssljson_${CFSSL_VERSION}_darwin_amd64"
chmod +x cfssl cfssljson
sudo mv cfssl cfssljson /usr/local/bin
```

---

## Provisioning CA and Generating TLS Certs

Everything here it to be done on a local machine.

I have chosen to create a single certificate for all communication for this guide. In a production
cluster, it is recommended that a TLS certificate be generated for each component.

### Create the CA Configuration File

```
cat ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF
```

### Generate the CA Certificate and Private Key

#### Create the CA CSR

```
cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CA",
      "ST": "Ontario",
      "L": "Hamilton",
      "O": "Kubernetes",
      "OU": "CA"
    }
  ]
}
EOF
```

#### Generate the CA Certificate and Private Key

```
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

#### Verify

```
openssl x509 -in ca.pem -text -noout
```

### Generate the Kubernetes Certificate and Private Key

#### Create the Kubernetes CSR

```
cat > kubernetes-csr.json <<EOF
{
  "CN": "Kubernetes",
  "hosts": [
    "k8s-controller-0",
    "k8s-node-0",
    "k8s-node-1",
    "k8s-node-2",
    "192.168.1.110",
    "192.168.1.120",
    "192.168.1.121",
    "192.168.1.122",
    "127.0.0.1"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CA",
      "ST": "Ontario",
      "L": "Hamilton",
      "O": "Kubernetes",
      "OU": "CA"
    }
  ]
}
EOF
```

#### Generate the Kubernetes Certificate and Private Key

```
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
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

```
for instance in k8s-node-1 k8s-node-2 k8s-node-3; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CA",
      "L": "Hamilton",
      "O": "system:nodes"
    }
  ]
}
EOF

INTERNAL_IP=$('192.168.1.201', '192.168.1.202', '192.168.1.203')

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance},${INTERNAL_IP} \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done


cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=config/certificate-authority/ca-config.json \
  -hostname=k8s-node-1,192.168.1.201 \
  -profile=kubernetes \
  config/kubelet-client-certificates/k8s-node-1-csr.json | cfssljson -bare k8s-node-1


cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=config/certificate-authority/ca-config.json \
  -hostname=k8s-node-2,192.168.1.202 \
  -profile=kubernetes \
  config/kubelet-client-certificates/k8s-node-2-csr.json | cfssljson -bare k8s-node-2


cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=config/certificate-authority/ca-config.json \
  -hostname=k8s-node-3,192.168.1.203 \
  -profile=kubernetes \
  config/kubelet-client-certificates/k8s-node-3-csr.json | cfssljson -bare k8s-node-3




cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CA",
      "L": "Hamilton",
      "O": "system:kube-controller-manager"
    }
  ]
}
EOF


cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=config/certificate-authority/ca-config.json \
  -profile=kubernetes \
  config/controller-manager-client-certificate/kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager



cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CA",
      "L": "Hamilton",
      "O": "system:node-proxier"
    }
  ]
}
EOF



cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=config/certificate-authority/ca-config.json \
  -profile=kubernetes \
  config/kube-proxy-client-certificate/kube-proxy-csr.json | cfssljson -bare kube-proxy



cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CA",
      "L": "Hamilton",
      "O": "system:kube-scheduler"
    }
  ]
}
EOF



cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=config/certificate-authority/ca-config.json \
  -profile=kubernetes \
  config/scheduler-client-certificate/kube-scheduler-csr.json | cfssljson -bare kube-scheduler




{

KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.svc.cluster.local

cat > config/api-server-certificate/kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CA",
      "L": "Hamilton",
      "O": "Kubernetes"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=config/certificate-authority/ca-config.json \
  -hostname=10.32.0.1,192.168.1.200,23.92.128.203,127.0.0.1,${KUBERNETES_HOSTNAMES} \
  -profile=kubernetes \
  config/api-server-certificate/kubernetes-csr.json | cfssljson -bare kubernetes

}





{

cat > config/service-account-key-pair/service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CA",
      "L": "Hamilton",
      "O": "Kubernetes"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=config/certificate-authority/ca-config.json \
  -profile=kubernetes \
  config/service-account-key-pair/service-account-csr.json | cfssljson -bare service-account

}



for instance in k8s-node-1 k8s-node-2 k8s-node-3; do
  scp ca.pem ${instance}-key.pem ${instance}.pem root@${instance}:~/
done

for instance in k8s-master-1; do
  scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem service-account-key.pem service-account.pem root@${instance}:~/
done


for instance in controller-0 controller-1 controller-2; do
  gcloud compute scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem ${instance}:~/
done






for instance in k8s-node-1 k8s-node-2 k8s-node-3; do
  kubectl config set-cluster k8s-pi-cluster \
    --certificate-authority=../../certs/ca.pem \
    --embed-certs=true \
    --server=https://192.168.1.200:6443 \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=../../certs/${instance}.pem \
    --client-key=../../certs/${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=k8s-pi-cluster \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done




{
  kubectl config set-cluster k8s-pi-cluster \
    --certificate-authority=../../certs/ca.pem \
    --embed-certs=true \
    --server=https://192.168.1.200:6443 \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=../../certs/kube-proxy.pem \
    --client-key=../../certs/kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-context default \
    --cluster=k8s-pi-cluster \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
}



{
  kubectl config set-cluster k8s-pi-cluster \
    --certificate-authority=../../certs/ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=../../certs/kube-controller-manager.pem \
    --client-key=../../certs/kube-controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-context default \
    --cluster=k8s-pi-cluster \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig
}




{
  kubectl config set-cluster k8s-pi-cluster \
    --certificate-authority=../../certs/ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=../../certs/kube-scheduler.pem \
    --client-key=../../certs/kube-scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster=k8s-pi-cluster \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig
}


{
  kubectl config set-cluster k8s-pi-cluster \
    --certificate-authority=../../certs/ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=../../certs/admin.pem \
    --client-key=../../certs/admin-key.pem \
    --embed-certs=true \
    --kubeconfig=admin.kubeconfig

  kubectl config set-context default \
    --cluster=k8s-pi-cluster \
    --user=admin \
    --kubeconfig=admin.kubeconfig

  kubectl config use-context default --kubeconfig=admin.kubeconfig
}



for instance in k8s-node-1 k8s-node-2 k8s-node-3; do
  scp config/kubelet/${instance}.kubeconfig config/kube-proxy/kube-proxy.kubeconfig root@${instance}:~/
done


for instance in k8s-master-1; do
  scp config/kube-scheduler/admin.kubeconfig config/kube-controller-manager/kube-controller-manager.kubeconfig config/kube-scheduler/kube-scheduler.kubeconfig root@${instance}:~/
done





ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > encryption-config.yaml <<EOF
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

scp encryption-config.yaml root@k8s-master-1:~/




# On k8s-master-1

wget -q --show-progress --https-only --timestamping "https://github.com/etcd-io/etcd/releases/download/v3.4.15/etcd-v3.4.15-linux-amd64.tar"

tar -xvf etcd-v3.4.15-linux-arm64.tar
mv etcd-v3.4.15-linux-arm64/etcd* /usr/local/bin


mkdir -p /etc/etcd /var/lib/etcd
chmod 700 /var/lib/etcd
cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/

systemctl enable systemd-resolved.service
systemctl start systemd-resolved.service

cat <<EOF | tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
Environment="ETCD_UNSUPPORTED_ARCH=arm64"
Type=notify
ExecStart=/usr/local/bin/etcd \
  --name k8s-master-1 \
  --cert-file=/etc/etcd/kubernetes.pem \
  --key-file=/etc/etcd/kubernetes-key.pem \
  --peer-cert-file=/etc/etcd/kubernetes.pem \
  --peer-key-file=/etc/etcd/kubernetes-key.pem \
  --trusted-ca-file=/etc/etcd/ca.pem \
  --peer-trusted-ca-file=/etc/etcd/ca.pem \
  --peer-client-cert-auth \
  --client-cert-auth \
  --initial-advertise-peer-urls https://192.168.1.200:2380 \
  --listen-peer-urls https://192.168.1.200:2380 \
  --listen-client-urls https://192.168.1.200:2379,https://127.0.0.1:2379 \
  --advertise-client-urls https://192.168.1.200:2379 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-cluster k8s-master-1=https://192.168.1.200:2380 \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable etcd
systemctl start etcd

# Check /var/log/syslog for errors


mkdir -p /etc/kubernetes/config


wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.20.4/bin/linux/arm64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.20.4/bin/linux/arm64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.20.4/bin/linux/arm64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.20.4/bin/linux/arm64/kubectl"


{
  chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
  mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
}


{
  mkdir -p /var/lib/kubernetes/

  mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem \
    encryption-config.yaml /var/lib/kubernetes/
}





cat <<EOF | tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=192.168.1.200 \\
  --allow-privileged=true \\
  --apiserver-count=1 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://192.168.1.200:2379\\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --runtime-config='api/all=true' \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-account-signing-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-account-issuer=api \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF




mv kube-controller-manager.kubeconfig /var/lib/kubernetes/






cat <<EOF | tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --allocate-node-cidrs=true \\
  --bind-address=0.0.0.0 \\
  --cluster-cidr=10.16.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --node-cidr-mask-size=24 \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


mv kube-scheduler.kubeconfig /var/lib/kubernetes/



cat <<EOF | tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF


cat <<EOF | tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF




# just run on one of the controller nodes (k8s-master-1)

cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
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



cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
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
