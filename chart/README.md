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

## Upgrading to v1

### Install new Traefik CRDs
```shell
kubectl apply --server-side --force-conflicts -k https://github.com/traefik/traefik-helm-chart/traefik/crds/
```

### Upgrade Peaka
```shell
helm repo update
helm upgrade peaka peaka/peaka
```

### (Optional) Delete old Traefik CRDs
This step is optional as the upgrade will use new CRDs.
```shell
kubectl delete -k https://github.com/traefik/traefik-helm-chart/traefik/crds?ref=v20.8.0
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


- Peaka appilaction utilizes [Traefik Proxy](https://traefik.io/traefik) for some internal routing configurations and 
exposing Peaka to outside world. Read [Exposing Peaka](#exposing-peaka) for more information.

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

### Exposing Peaka
Peaka application is accessible through the Traefik service deployed with this chart. By default, it is only available 
inside the cluster (`ClusterIP`).

**1. Choose service type**

If you want to expose Peaka externally, update the `traefik.service.type` field in your `values.yaml`:
```yaml
traefik:
  service:
    type: LoadBalancer    # or NodePort / ClusterIP
```
- **ClusterIP** (default): Internal access only.
- **NodePort**: Expose the app on each node’s IP at a fixed port.
- **LoadBalancer**: Create an external load balancer (requires cloud provider support).

**2. Choose ports to expose**
- Peaka Studio Web Application
  - Without TLS termiantion in Peaka:
    ```yaml
    traefik:
      ports:
        web:
          expose: true
          nodePort: 30080   # set this if using NodePort or LoadBalancer, otherwise Kubernetes will assign a random port    
    ```

  - With TLS termination in Peaka:
    ```yaml
    traefik:
      ports:
        websecure:
          expose: true
          nodePort: 30443   # set this if using NodePort or LoadBalancer, otherwise Kubernetes will assign a random port
    ```

- Peaka JDBC Service
  ```yaml
  traefik:
    ports:
      dbc:
        expose: true
        nodePort: 30567     # set this if using NodePort or LoadBalancer, otherwise Kubernetes will assign a random port
  ```

For more information about Traefik's installation parameters, consult the 
[Traefik Helm Chart](https://github.com/traefik/traefik-helm-chart).

## Known Limitations
- If you are accessing Peaka from a hostname which is not localhost, then you need to enable TLS to access Peaka studio 
web application. If TLS is terminated before the traffic reaches Peaka app, then TLS of this chart
should be disabled by setting `tls.enabled` to false in `values.yaml`. If you plan to have Peaka terminate TLS, then set 
`tls.enabled` to true and enter certificate details in `tls.cert` and `tls.key` in `values.yaml`. 
