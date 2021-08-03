#!/usr/bin/env bash

# Source all the functions.

source "$(dirname -- "$0")/generate-certs.sh"
source "$(dirname -- "$0")/generate-config.sh"
source "$(dirname -- "$0")/generate-encryption-config.sh"
source "$(dirname -- "$0")/generate-etcd-config.sh"
source "$(dirname -- "$0")/generate-kubeconfig.sh"

# Execute the functions.

generate_certs
generate_config
generate_encryption_config
generate_etcd_config
generate_kubeconfig

