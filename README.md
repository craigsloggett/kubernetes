# Kubernetes The Hard Way for a Raspberry Pi Cluster

This tutorial is a fork of Kelsey Hightower's [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way), updated with instructions for deploying to a Raspberry Pi Cluster.

## Target Audience

The target audience for this tutorial is someone who has a set of Raspberry Pis and would like to use them to build a Kubernetes cluster and understand how everything fits together.

## Cluster Details

Just like [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way), this tutorial guides you through bootstrapping a highly available Kubernetes cluster with end-to-end encryption between components and RBAC authentication.

* [kubernetes](https://github.com/kubernetes/kubernetes) v1.22.2
* [etcd](https://github.com/etcd-io/etcd) v3.5.0
* [cri-o](https://github.com/cri-o/cri-o) v1.21.3
* [crun](https://github.com/containers/crun) v1.0
* [cni](https://github.com/containernetworking/plugins) v0.9.1
* [coredns](https://github.com/coredns/coredns) v1.8.4

## Labs

* [Prerequisites](docs/01-prerequisites.md)
* [Installing the Client Tools](docs/02-client-tools.md)
* [Provisioning Compute Resources](docs/03-compute-resources.md)
* [Provisioning the CA and Generating TLS Certificates](docs/04-certificate-authority.md)
* [Generating Kubernetes Configuration Files for Authentication](docs/05-kubernetes-configuration-files.md)
* [Generating the Data Encryption Config and Key](docs/06-data-encryption-keys.md)
* [Bootstrapping the etcd Cluster](docs/07-bootstrapping-etcd.md)
* [Bootstrapping the Kubernetes Control Plane](docs/08-bootstrapping-kubernetes-controllers.md)
* [Bootstrapping the Kubernetes Worker Nodes](docs/09-bootstrapping-kubernetes-workers.md)
* [Configuring kubectl for Remote Access](docs/10-configuring-kubectl.md)
* [Provisioning Pod Network Routes](docs/11-pod-network-routes.md)
* [Deploying the DNS Cluster Add-on](docs/12-dns-addon.md)
* [Smoke Test](docs/13-smoke-test.md)
* [Cleaning Up](docs/14-cleanup.md)
