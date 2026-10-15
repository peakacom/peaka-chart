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

## Sizing

Every main container sets a memory request, a memory limit and a CPU request (no CPU limits); init containers
and the Temporal schema Jobs set none. Heaps:
- be-* Java services: 70% of the memory limit (`JAVA_TOOL_OPTIONS=-XX:MaxRAMPercentage=70.0`), so raise a
  service's limit to give it more heap.
- Trino: `trino.*.jvm.maxRAMPercentage` of the limit, or a fixed `trino.*.jvm.maxHeapSize`.
- Hive metastore: `hiveMetastore.hadoopHeapSize` (MB); change it together with the limit.
- Kafka: a fixed 1 GiB (`kafka.controller.heapOpts`). Kafka Connect: 75% of the limit.
- Node services (collab, search, MCP and the flow-utilities sidecars): one fixed 768 MiB for all
  (`NODE_OPTIONS=--max-old-space-size=768`). A higher limit does not raise it; keep their limits ≥ 1Gi.

| Profile | Nodes | Values |
|---|---|---|
| Trial / PoC | 1 × 8 vCPU / 32 GiB | chart defaults (≈ 24 GiB and 6 vCPU of requests) |
| Production | 3 × 16 vCPU / 64 GiB | `-f values-production.yaml`: one Trino worker per node (36Gi), coordinator 12Gi, other requests × 1.5 |

Get the production file from the chart package and deploy that same chart, so chart and file match:
```shell
helm pull peaka/peaka --version <version> --untar --untardir <version>
helm upgrade -n peaka [RELEASE_NAME] ./<version>/peaka -f <version>/peaka/values-production.yaml -f my-values.yaml
```

### Upgrading an existing install
- Pass your own values with `-f`; do not use `--reuse-values`, which keeps the old chart's empty `resources`
  under the new heap settings (`--reset-then-reuse-values`, Helm ≥ 3.14, is fine).
- Trino's heap now follows its limit and per-node query memory defaults to 30% of the heap: the default worker
  goes from 15 GB to ≈ 5.4 GB per node, the production worker to ≈ 8.6 GB, and a coordinator-only install
  (`trino.server.workers: 0`) from 9 GB to ≈ 1.2 GB. To keep 15 GB per worker, set
  `trino.worker.config.query.maxMemoryPerNode: 15GB`; that alone fits the production worker's ≈ 28.8 GB heap.
  The default worker also needs `trino.worker.jvm.maxHeapSize: 50G` and `trino.worker.resources.limits.memory`
  ≥ 63Gi, on nodes with that much memory free.
- If you keep an override of `trino.*.jvm.maxHeapSize`, `trino.*.config.query.maxMemoryPerNode`,
  `hiveMetastore.hadoopHeapSize` or `kafkaConnect.heapOptions`, re-size it to the new limits:
  - each heap ≤ 80% of its memory limit, and for Trino heap + `jvm.maxDirectMemorySize` + 10% of the
    heap + 2 GiB ≤ the limit, or the pod is OOM-killed;
  - Trino's `maxMemoryPerNode` + `config.memory.heapHeadroomPerNode` (default 30% of the heap) < the heap,
    or Trino refuses to start (`Invalid memory configuration`) and the pod crash-loops.
- If the namespace has a ResourceQuota or LimitRange, check it against the new totals before upgrading:
  - quota ≥ the profile's requests and limits plus the rollout surge: about 35 Deployments restart at once,
    each starting its new pod before it stops the old one. With the surge that is ≈ 36 GiB / 8.7 vCPU of
    requests and ≈ 157 GiB of limits by default, ≈ 164 GiB / 10.7 vCPU and ≈ 245 GiB in production;
  - LimitRange max ≥ the largest limit (24Gi, production 36Gi), min ≤ the smallest request (32Mi / 50m);
  - `maxLimitRequestRatio`: memory ≥ 16; CPU absent, or ≥ the default CPU limit / 50m;
  - a default CPU limit re-adds CPU limits: it must be ≥ 1 (Trino's CPU request), or the Trino pods are rejected
    (request > limit). Remove it only if no quota covers `limits.cpu` and no CPU `maxLimitRequestRatio` is set,
    since no container sets its own CPU limit; a `limits.cpu` quota needs one default per container, ≈ 82 × the
    default during the rollout (production ≈ 84 ×);
  - init containers and the Temporal schema Jobs set no resources, so with a quota on requests or limits the
    LimitRange must give them defaults.
- Production: you need ≥ 3 schedulable nodes, each with ≈ 44 GiB allocatable free for Peaka, and the node that
  runs the Trino coordinator ≈ 56 GiB (`kubectl describe nodes`). Trino workers use `Recreate`, so all old
  workers stop first; if a new one stays `Pending`, run `helm rollback`.

### Tainted nodes
`global.tolerations` does not reach every pod. Also set `temporal.server.tolerations`,
`temporal.admintools.tolerations` (schema Job), `pgcat.tolerations`, `kafka.controller.tolerations`,
`mongodb.tolerations`, `redis.master.tolerations`, `minio.tolerations`, `traefik.tolerations` and
`permify.tolerations`. The in-chart Postgres has no tolerations setting: on tainted-only nodes use
`externalPostgresql`.

## Known Limitations
- If you are accessing Peaka from a hostname which is not localhost, then you need to enable TLS to access Peaka studio 
web application. If TLS is terminated before the traffic reaches Peaka app, then TLS of this chart
should be disabled by setting `tls.enabled` to false in `values.yaml`. If you plan to have Peaka terminate TLS, then set 
`tls.enabled` to true and enter certificate details in `tls.cert` and `tls.key` in `values.yaml`. 
