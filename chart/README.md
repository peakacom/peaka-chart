# Peaka Helm Chart

This Helm chart deploys Peaka in a Kubernetes cluster.

## Prerequisites

- Kubernetes 1.22+
- Helm 3+
- PV provisioner support in the underlying infrastructure

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

### Install Traefik CRDs
Peaka uses Traefik `IngressRoute` and `Middleware` resources for routing. The
Traefik CRDs must be applied to the cluster **before** `helm install`. Every
chart release publishes a CRD bundle alongside it, so you can apply the bundle
that matches whichever chart version you start from:

```shell
kubectl apply -f https://peaka-chart.storage.googleapis.com/crds/traefik-crds-<CHART_VERSION>.yaml
```

Replace `<CHART_VERSION>` with the chart version you intend to install (e.g.
`1.1.0-beta.12`).

**You do not need to re-apply the CRDs on every chart upgrade.** The contents
of the CRD bundle only change when this chart starts depending on a new
Traefik version. When that happens, the release notes for that chart version
will call it out explicitly and tell you to re-run the `kubectl apply` above
with the new bundle URL before running `helm upgrade`. As long as the release
notes don't say so, upgrading the chart will keep working against the CRDs you
applied at install time.

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

### Log Collection (optional)
The chart can collect the logs of every container in the release namespace with
[Fluent Bit](https://fluentbit.io) and store them in a bundled [OpenObserve](https://openobserve.ai)
instance, so logs survive pod restarts and can be searched later. Both are off by default.

```yaml
logging:
  fluentBit:
    enabled: true        # DaemonSet, one pod per node
  openobserve:
    enabled: true        # StatefulSet with a 10Gi PVC
    retentionDays: 7
```

Open the OpenObserve UI with (`<fullname>` is the release name if it contains `<name>`, otherwise
`<release>-<name>`, where `<name>` is `nameOverride` or else `peaka`; `fullnameOverride` replaces it):
```shell
kubectl -n <namespace> port-forward svc/<fullname>-openobserve 5080:5080
kubectl -n <namespace> get secret <fullname>-openobserve -o jsonpath='{.data.ZO_ROOT_USER_PASSWORD}' | base64 -d
```
Then browse `http://localhost:5080` and log in with `logging.openobserve.rootUserEmail` (its value at first
install; later changes are ignored) and that password.
Logs are in the `fluent_bit_kube` stream. To supply your own credentials, create a Secret with the keys
`ZO_ROOT_USER_EMAIL`, `ZO_ROOT_USER_PASSWORD` and `ZO_ROOT_USER_TOKEN` and set
`logging.openobserve.existingSecret`. Set it also when the chart is rendered without cluster access
(Argo CD, `helm template`): the generated Secret keeps its values through `lookup`, so each such render
creates new ones that OpenObserve's root user does not match. Fluent Bit only receives the email and the
token, which OpenObserve accepts on ingestion endpoints only.

Security notes:
- Fluent Bit runs as root and mounts the node paths `/var/log/pods` and `/var/log/containers`
  (read-only) plus `/var/lib/fluent-bit/<namespace>-<release>` (read offsets). Namespaces enforcing the
  PodSecurity `baseline` or `restricted` level reject it; OpenShift needs a SCC allowing hostPath.
- On Docker-runtime nodes (e.g. RKE1) the log files live under Docker's data dir: set
  `logging.fluentBit.dockerContainersDir: /var/lib/docker/containers`. Fluent Bit can then also read every
  container's config there, including its environment (secrets such as the OpenObserve root password).
- On SELinux-enforcing nodes (e.g. OpenShift, RHEL) the default container type cannot read the log files or
  write the offsets directory: set `logging.fluentBit.securityContext.seLinuxOptions.type: spc_t` (on
  OpenShift the SCC must allow that type too).
- It tails only the release namespace's log files, though it can read every pod's log files on its node,
  and gets a namespaced Role (read pods), no cluster-wide access.
- For air-gapped installs, mirror `cr.fluentbit.io/fluent/fluent-bit` and `o2cr.ai/openobserve/openobserve`
  and set `logging.fluentBit.image` / `logging.openobserve.image` to the mirrored names.

## Known Limitations
- If you are accessing Peaka from a hostname which is not localhost, then you need to enable TLS to access Peaka studio 
web application. If TLS is terminated before the traffic reaches Peaka app, then TLS of this chart
should be disabled by setting `tls.enabled` to false in `values.yaml`. If you plan to have Peaka terminate TLS, then set 
`tls.enabled` to true and enter certificate details in `tls.cert` and `tls.key` in `values.yaml`. 
