# Peaka Helm Chart

This Helm chart deploys Peaka in a Kubernetes cluster.

## Prerequisites

- Kubernetes 1.22+
- Helm 3+
- PV provisioner support in the underlying infrastructure
- cert-manager installed on the cluster

## Installation
### Get repository
```shell
helm repo add peaka https://peaka-chart.storage.googleapis.com/charts
helm repo update
```

### Create Peaka Namespace
```shell
kubectl create namespace peaka
```

### Install
```shell
helm install -n peaka [RELEASE_NAME] peaka/peaka
```

## Configuration
Some configurations must be set for Peaka to run as expected. 

- Peaka's container images are not publicly available. You will be given a `json` file containing access credentials 
  to Peaka's container image registry. You need to set `.Values.imagePullSecret.gcpRegistryAuth.password` 
  to the content of the `json` file. This will create a Kubernetes Secret of type `docker-registry`, which Peaka 
  services will use as imagePullSecret.


- Peaka services need to know the URL and port through which the services will be accessed beforehand. For that, you
need to fill `accessUrl` parameter in `values.yaml`. Read [Configuring Access URLs](#configuring-access-urls)
section for detailed explanation.

### Configuring Access URLs
Before deploying Peaka, you must configure how the services will be accessed by setting the `accessUrl` parameters in `values.yaml`. These settings are crucial for:
- Proper CORS (Cross-Origin Resource Sharing) policy configuration
- Correct URI generation in API responses
- Accurate JDBC connection strings

Update the following parameters in your `values.yaml`:
- `accessUrl.domain`: The domain name or IP address where your services will be accessible (e.g., "localhost", "peaka.example.com")
- `accessUrl.scheme`: The URL scheme ("http" or "https")
- `accessUrl.port`: The port number for accessing the Studio web application (default: 8000)
- `accessUrl.dbcPort`: The port number for JDBC service connections (default: 4567)

For example, if you want to access Peaka from localhost, fill the `accessUrl` parameter as below:
```yaml
accessUrl:
  domain: "localhost"
  scheme: "http"
  port: 8000
  dbcPort: 4567
```
Install the Peaka helm chart, and run `kubectl port-forward`:
```shell
export POD_NAME=$(kubectl get pods --namespace <namespace> -l "app.kubernetes.io/name=traefik" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $POD_NAME 8000 --namespace <namespace>
```
Now, you can access Peaka Studio web application through `http://localhost:8000`.  

Similarly, if you run
```shell
export POD_NAME=$(kubectl get pods --namespace <namespace> -l "app.kubernetes.io/name=traefik" -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward $POD_NAME 4567 --namespace <namespace>
```
you can use the Peaka JDBC service using `http://localhost:4567`.

## Known Limitations
- If you are accessing Peaka from a hostname which is not localhost, then you need to enable TLS to access Peaka studio 
web application. To enable TLS, update `tls.enabled`, `tls.cert` and `tls.key` parameters in `values.yaml`. 
