#!/usr/bin/env bash

# Configuration Parameters

resources_dir="$(dirname -- "$0")/tmp/resources"
encryption_key="$(head -c 32 /dev/urandom | base64)"

# Create a place to store the encryption resource file.
[ ! -d "$resources_dir" ] && mkdir -p "$resources_dir"
cd "$resources_dir" || exit

# ---

# Encryption Configuration

cat > encryption-config.yaml <<- EOF
	kind: EncryptionConfig
	apiVersion: v1
	resources:
	  - resources:
	      - secrets
	    providers:
	      - aescbc:
	          keys:
	            - name: key1
	              secret: ${encryption_key}
	      - identity: {}
EOF

