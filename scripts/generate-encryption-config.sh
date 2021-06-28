#!/usr/bin/env bash

# Configuration Parameters

encryption_key="$(head -c 32 /dev/urandom | base64)"

# Create a place to store the configuration file.
[ ! -d "../resources" ] && mkdir "../resources"
cd "../resources" || exit

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

