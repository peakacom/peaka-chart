# Peaka Helm Chart

This Helm chart deploys Peaka in a Kubernetes cluster.

## Prerequisites

- Kubernetes 1.22+
- Helm 3+
- cert-manager CRDs:  
  Peaka depends on Temporal to run flows, which require cert-manager CRDs. To install them:
  ```shell
  kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.1/cert-manager.crds.yaml
  ```
- Peaka's container images are not publicly available. This means that a Kubernetes Secret of type `docker-registry`
will be required. With the given `json` file containing access credentials to Peaka's container image registry, 
run (in the same namespace in which you'll install Peaka):
  ```shell
  kubectl create secret docker-registry <image-pull-secret-name> \
    --docker-server=https://europe-west3-docker.pkg.dev \
    --docker-username=_json_key \
    --docker-password=<path/to/given/json/file> \
    --docker-email=not@val.id
  ```
  Then, add the name of this secret to `.Values.imagePullSecrets`.
