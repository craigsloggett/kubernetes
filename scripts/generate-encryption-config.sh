#!/usr/bin/env bash

# Run this in a subshell to avoid having to deal with changing directories.
generate_encryption_config() (
	local resources_dir="$(dirname -- "$0")/.output/resources"
	local encryption_key="$(head -c 32 /dev/urandom | base64)"
	
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
)

