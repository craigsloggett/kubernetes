# Provisioning CA and Generating TLS Certificates

Using CloudFlare's PKI toolkit, `cfssl`, a Certificate Authority is bootstrapped and then used to generate TLS certificates for the following components: 
 - etcd
 - kube-apiserver
 - kube-controller-manager
 - kube-scheduler
 - kubelet
 - kube-proxy

## Authentication

For Kubernetes certificates best practices, reference this document:
https://kubernetes.io/docs/setup/best-practices/certificates/

For details on how Kubernetes authenticates using signed certificates, reference this document:
https://kubernetes.io/docs/reference/access-authn-authz/authentication/

> Kubernetes determines the username from the common name field in the 'subject' of the cert (e.g., "/CN=bob").

Client certificates will be generated to authenticate API requests for each of the following roles:
 - admin
 - system:kube-controller-manager
 - system:kube-proxy
 - system:kube-scheduler

Additionally, a service account client certificate will be generated to authenticate service account
API requests.

## Authorization

For details on security best practices, refer to this document:
https://kubernetes.io/docs/tasks/administer-cluster/securing-a-cluster/

> It is recommended that you use the Node and RBAC authorizers together, in combination with the NodeRestriction admission plugin.

For details on node authorization, refer to this document:
https://kubernetes.io/docs/reference/access-authn-authz/node/

> In order to be authorized by the Node authorizer, kubelets must use a credential that identifies them as being in the `system:nodes` group, with a username of `system:node:<nodeName>`.

When generating the kubelet client certificates, the CN must be `system:node:<nodeName>` where 
`<nodeName>` will be the hostname of the node the certificate is being generated for.

## Genertaing TLS Certs

All certificates are generated using the script found here: 
https://github.com/nerditup/kubernetes/blob/main/scripts/generate-certs.sh

### Verify

```
openssl x509 -in <certificate_name.pem> -text -noout
```

For convenience, the following will iterate over all certificates that were generated:

```
for file in *.pem;
do
  case "${file}" in
    *key*)
      : # Do nothing.
    ;;

    *)
      printf '---\n%s\n---\n' "${file}"
      openssl x509 -in "${file}" -text -noout
    ;;
  esac
done
```

## Distribute the TLS Certificates

Distribute the appropriate certificates and private keys to each controller host:

```
for host in controller-0; do
  ssh nerditup@${host} 'mkdir -p ~/kubernetes/certs'
  scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    sa-key.pem sa.pem nerditup@${host}:~/kubernetes/certs
done
```

Distribute the appropriate certificates and private keys to each node host:

```
for host in node-0 node-1 node-2; do
  ssh nerditup@${host} 'mkdir -p ~/kubernetes/certs'
  scp ca.pem "${host}"-key.pem "${host}".pem nerditup@${host}:~/kubernetes/certs
done
```

**Note:** For the certificates that were created but not distributed, they are used to generate the kubeconfig files with embedded certificates.

Next: [Generating Kubernetes Configuration Files for Authentication](05-kubernetes-configuration-files.md)
