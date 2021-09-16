# Installing the Client Tools

In this lab you will install the command line utilities required to complete this tutorial: [cfssl](https://github.com/cloudflare/cfssl), [cfssljson](https://github.com/cloudflare/cfssl), and [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl). The local machine used in this tutorial is a MacBook running an amd64 processor.


## Install CFSSL

The `cfssl` and `cfssljson` command line utilities will be used to provision a [PKI Infrastructure](https://en.wikipedia.org/wiki/Public_key_infrastructure) and generate TLS certificates.

Download and install `cfssl` and `cfssljson`:

### macOS

```
(
  export CFSSL_VERSION="1.5.0"
  curl -o cfssl -L "https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssl_${CFSSL_VERSION}_darwin_amd64"
  curl -o cfssljson -L "https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssljson_${CFSSL_VERSION}_darwin_amd64"
)
```

```
chmod +x cfssl cfssljson
```

```
mv cfssl cfssljson ~/.local/bin
```

### Verification

Verify `cfssl` and `cfssljson` version 1.5.0 are installed:

```
cfssl version
```

> Output

```
Version: 1.5.0
Runtime: go1.12.12
```

```
cfssljson --version
```

> Output

```
Version: 1.5.0
Runtime: go1.12.12
```

## Install kubectl

The `kubectl` command line utility is used to interact with the Kubernetes API Server. Download and install `kubectl` from the official release binaries:

### macOS

```
(
  export KUBE_VERSION="1.22.2"
  curl -O -L "https://storage.googleapis.com/kubernetes-release/release/v${KUBE_VERSION}/bin/darwin/amd64/kubectl"
)
```

```
chmod +x kubectl
```

```
mv kubectl ~/.local/bin
```

### Verification

Verify `kubectl` version 1.21.1 is installed:

```
kubectl version --client
```

> Output

```
Client Version: version.Info{Major:"1", Minor:"22", GitVersion:"v1.22.2", GitCommit:"8b5a19147530eaac9476b0ab82980b4088bbc1b2", GitTreeState:"clean", BuildDate:"2021-09-15T21:38:50Z", GoVersion:"go1.16.8", Compiler:"gc", Platform:"darwin/amd64"}
```

Next: [Provisioning Compute Resources](03-compute-resources.md)
