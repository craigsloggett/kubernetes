# Generating Kubernetes Configuration Files for Authentication

Generate the kubeconfig files for the following components:
 - admin
 - kube-controller-manager
 - kube-proxy
 - kube-scheduler
 - kubelet

## Generating Kubernetes Configuration Files

All kubeconfig files are generated using the script found here: 
https://github.com/nerditup/kubernetes/blob/main/scripts/generate-kubeconfig.sh

## Distribute the Kubernetes Configuration Files

Distribute the `admin`, `kube-controller-manager` and `kube-scheduler` kubeconfig files to each controller host:

```
for host in controller-0; do
  ssh nerditup@${host} 'mkdir -p ~/kubernetes/kubeconfig'
  scp admin.conf kube-controller-manager.conf kube-scheduler.conf nerditup@${host}:~/kubernetes/kubeconfig
done
```

Distribute the `kubelet` and `kube-proxy` kubeconfig files to each node host:

```
for host in node-0 node-1 node-2; do
  ssh nerditup@${host} 'mkdir -p ~/kubernetes/kubeconfig'
  scp ${host}-kubelet.conf kube-proxy.conf nerditup@${host}:~/kubernetes/kubeconfig
done
```

Next: [Generating the Data Encryption Config and Key](06-data-encryption-keys.md)
