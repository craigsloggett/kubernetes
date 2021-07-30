#!/usr/bin/env bash

# ---
# CERTS
# Configuration Parameters

export CONTROLLER_HOSTNAME="controller-0"
export CONTROLLER_IP="192.168.1.110"
export INTERNAL_CLUSTER_DNS_IP="10.96.0.1"

# I've implemented a poor man's key:value store
# so the variable names align with the hostnames
# set below. The keys are determined dynamically
# in a loop, so the variable names aren't used
# explicitly -- disabling SC2034 as a result.

export NODE_HOSTNAMES=("node-0" "node-1" "node-2")
# shellcheck disable=SC2034
export NODE_0_IP="192.168.1.120"
# shellcheck disable=SC2034
export NODE_1_IP="192.168.1.121"
# shellcheck disable=SC2034
export NODE_2_IP="192.168.1.122"

# ---
# KUBECONFIG
# Configuration Parameters

#export NODE_HOSTNAMES=("node-0" "node-1" "node-2")
export CLUSTER_NAME="kubernetes"
export PUBLIC_IP="192.168.1.110"  # Same as CONTROLLER_IP

# ---
# API
# Configuration Parameters

export CONFIG_DIRECTORY="/etc/kubernetes"
export PKI_DIRECTORY="/etc/kubernetes/pki"
export SERVICE_CLUSTER_IP_RANGE="10.96.0.0/12"
export ADVERTISE_ADDRESS="192.168.1.110"

# ---
# CONTROLLER MANAGER
# Configuration Parameters

#export CONFIG_DIRECTORY="/etc/kubernetes"
export KUBECONFIG_DIRECTORY="/etc/kubernetes"
#export PKI_DIRECTORY="/etc/kubernetes/pki"
#export SERVICE_CLUSTER_IP_RANGE="10.96.0.0/12"

# ---
# SCHEDULER
# Configuration Parameters

#export CONFIG_DIRECTORY="/etc/kubernetes"
#export KUBECONFIG_DIRECTORY="/etc/kubernetes"

# ---
# KUBELET
# Configuration Parameters

#export CONFIG_DIRECTORY="/etc/kubernetes"
#export KUBECONFIG_DIRECTORY="/etc/kubernetes"
#export PKI_DIRECTORY="/etc/kubernetes/pki"
export DNS_SERVICE_IP="10.96.0.10"
export POD_INFRA_CONTAINER_IMAGE="k8s.gcr.io/pause:3.4.1"

# ---
# PROXY
# Configuration Parameters

#export CONFIG_DIRECTORY="/etc/kubernetes"
#export KUBECONFIG_DIRECTORY="/etc/kubernetes"

# ---
# ETCD
# Configuration Parameters

#export CONTROLLER_HOSTNAME="controller-0"
#export CONTROLLER_IP="192.168.1.110"
export ETCD_PKI_DIRECTORY="/etc/kubernetes/pki/etcd"

