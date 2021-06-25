# Generating the Data Encryption Configuration and Key

## Generate the Encryption Key and Configuration

The configuration is generated using the script found here: 
https://github.com/nerditup/kubernetes/blob/main/scripts/generate-encryption-config.sh

## Key Distribution
Distribute the `encryption-config` file to each controller host:

```
for host in controller-0; do
  scp encryption-config.yaml nerditup@${host}:~
done
```

Next: [Bootstrapping the etcd Cluster](07-bootstrapping-etcd.md)
