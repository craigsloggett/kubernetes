# Provisioning Compute Resources

Kubernetes requires a set of machines to host the Kubernetes control plane and the worker nodes where containers are ultimately run. In this lab you will provision the Raspberry Pis required for running a secure Kubernetes cluster. Additional Raspberry Pis can be added to ensure the cluster is highly available.

## Networking

The Kubernetes [networking model](https://kubernetes.io/docs/concepts/cluster-administration/networking/#kubernetes-model) assumes a flat network in which containers and nodes can communicate with each other. In cases where this is not desired [network policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) can limit how groups of containers are allowed to communicate with each other and external network endpoints.

> Setting up network policies is out of scope for this tutorial.

### Private Network

This cluster will be deployed to a local network behind a physical router. Commodity hardware is sufficient for this tutorial. The subnet used by the router should be large to assign a private IP address to each physical node in the Kubernetes cluster. Ideally, a static address is assigned to each node in the router configuration, matching the MAC address of the Raspberry Pi network adapters to an IP.

> The `192.168.1.0/24` IP address range can host up to 254 compute instances.

### Firewall Rules

All traffic within the local network should allow internal communication across all protocols. In order to access the cluster from outside the network, the router firewall must be configured to forward traffic to the cluster.

> Setting up the router firewall is out of scope for this tutorial.

### Load Balancing the Kubernetes API

Traffic to the API server can be load balanced across multiple control plane hosts to achieve high availability.

> Setting up a load balancer for a highly available control plane is out of scope for this tutorial.

### Kubernetes Public IP Address

The IP address allocated by an ISP to your local network would be used as the public facing IP. All traffic to this IP would be routed to the load balancer to then distribute requests across the control plane hosts in a highly available control plane configuration.

> Setting up a public facing IP address for the Kubernetes API is out of scope for this tutorial.

## Compute Instances

The compute instances in this lab will be provisioned using [Debian](https://www.debian.org/) 11 Testing (Bullseye), which has support for `cgroups v2` with `systemd version 244` or later. Older `systemd` versions do not support delegation of the `cpuset` controller which is important when imposing resource limitations on rootless containers.

> This tutorial does not leverage rootless containers.

### Download a Debian Raspberry Pi Image

```
curl -o raspi_4_bullseye.img.xz -L "https://raspi.debian.net/verified/20210413_raspi_4_bullseye.img.xz"
```

### Flash the SD Card

Once the SD card is plugged into the laptop, confirm the disk number assigned to this device (e.g. `/dev/disk2`).

```
xzcat raspi_4_bullseye.img.xz | sudo dd of=/dev/disk2 bs=64k
```

### Update Image Configuration

```
vim /Volumes/RASPIFIRM/sysconf.txt
# Uncomment and update the root_autherized_key value (e.g. pbcopy < ~/.ssh/id_ed25519.pub).
# Uncomment and update the hostname value (e.g. controller-0).
```

### Unmount the SD Card and Repeat

```
sudo diskutil unmount /Volumes/RASPIFIRM
```

Repeat this process for all Raspberry Pis.

## Configuring SSH Access

SSH access as the root user should be available since the image configuration contains the public SSH key of the laptop. Updating `/etc/hosts` might be required to access the Raspberry Pis depending on your network configuration.

Test SSH access to the `controller-0` Raspberry Pi:

```
ssh root@controller-0
```

Type `exit` at the prompt to exit the `controller-0` Raspberry Pi:

```
root@controller-0:~$ exit
```

> Output

```
logout
Connection to controller-0 closed.
```

## Preparing the Base OS

The Raspberry Pi images used are not fully equipped to run Kubernetes out of the box. The following steps will prepare the OS by cleaning up the `dmesg` logs, setup a regular user and ensure configuration that applies to all hosts is applied. Unfortunately, this is a manual process, for now!

The following is assumed to be done as the root user on all machines.

### Update the OS Packages

```
apt update
apt upgrade
```

### Check `dmesg` for Errors

```
dmesg
```

#### Add the Regulatory Database for Wireless Adapters

Since `git` is not available on the base Debian image, grab the necessary files using your laptop,

```
git clone https://kernel.googlesource.com/pub/scm/linux/kernel/git/sforshee/wireless-regdb
cd wireless-regdb
git checkout <latest-release-tag>  # e.g. master-2020-11-20
```

```
for host in controller-0 node-0 node-1 node-2
  do scp regulatory.db regulatory.db.p7s root@$host:/root
done
```

Now on the Raspberry Pis, we can put the firmware in the correct location.

```
mv /root/regulatory.db* /lib/firmware/
```

#### Install the Bluetooth Firmware

```
curl -o /lib/firmware/brcm/BCM4345C5.hcd "https://github.com/armbian/firmware/raw/master/brcm/BCM4345C5.hcd"
curl -o /lib/firmware/brcm/BCM4345C0.hcd "https://github.com/armbian/firmware/raw/master/BCM4345C0.hcd"
curl -o /lib/firmware/brcm/brcmfmac43455-sdio.clm_blob "https://github.com/armbian/firmware/raw/master/brcm/brcmfmac43455-sdio.clm_blob"
```

#### Validate

```
reboot
```

```
dmesg
```

> Output

```
# No errors in the output.
```

Next: [Provisioning a CA and Generating TLS Certificates](04-certificate-authority.md)
