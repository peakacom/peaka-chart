# Peaka Helm Chart

This Helm chart deploys Peaka in a Kubernetes cluster.

## Prerequisites

- Kubernetes 1.22+
- Helm 3+
- PV provisioner support in the underlying infrastructure
- cert-manager

## Installation
### Get repository
```shell
helm repo add peaka https://peaka-chart.storage.googleapis.com/charts
helm repo update
```

### Install
```shell
helm install [RELEASE_NAME] peaka/peaka
```

## Configuration
Some configurations must be set for Peaka to run as expected. 

- Peaka's container images are not publicly available. This means that a Kubernetes Secret of type `docker-registry`
  will be required. With the given `json` file containing access credentials to Peaka's container image registry,
  run (in the same namespace in which you'll install Peaka):
  ```shell
  kubectl create secret docker-registry <image-pull-secret-name> \
    --docker-server=https://europe-west3-docker.pkg.dev \
    --docker-username=_json_key \
    --docker-password="$(cat <path/to/given/json/file>)" \
    --docker-email=not@val.id
  ```
  Then, add the name of this secret to `.Values.imagePullSecrets`.
- Generate JWT public/private key pair encrypted with RSA and fill `.Values.jwtRsaPublicKey`
  and `.Values.jwtRsaPrivateKey`.
