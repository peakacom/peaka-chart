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

## Upgrading: Debezium Connect disabled

Debezium Connect (`kafkaConnect`, the CDC cache engine) is now disabled by default.
`monitoringKafkaConnect` is a different component and is not affected.

### Before upgrading
Run on Peaka's Postgres, in the database that holds the `studio` schema: `postgresql.primary.database` (default
`peaka_db`), or `externalPostgresql.database` (default `code2db`) with an external Postgres. For the in-cluster
Postgres with default values:
```shell
kubectl exec -n peaka <release>-postgres-0 -- psql -U peakadb -d peaka_db \
  -c "SELECT count(*) FROM studio.cdc_connection;" \
  -c "SELECT count(*) FROM studio.cache_settings WHERE cachetype = 1;"
```
A query error means the check has not run. If either count is above 0, contact Peaka before upgrading: each Postgres
CDC connection keeps a Debezium replication slot on its source database. Once Debezium Connect is gone nothing reads
that slot, and the source database keeps WAL for it without limit unless `max_slot_wal_keep_size` is set.

### What the upgrade does
- `helm upgrade` deletes the `<release>-kafka-connect` Deployment and Service. No Peaka volume or database is touched.
- CDC caches stop refreshing.
- Upgrade Studio (`studioWeb.image.tag`) together with the chart, to an image that hides the CDC cache menu. Images up
  to `v1.2.20` still show it, and creating a CDC cache from it fails.
- Leave the `<release>-kafka-connect-status`, `<release>-kafka-connect-offset` and `<release>-kafka-connect-config`
  topics in place. be-data-cache recreates them at every start and logs three `TopicExistsException` lines; this is
  expected. The `<release>-monitoring-kafka-connect-*` topics belong to `monitoringKafkaConnect`.

### Keeping CDC
Set this in your `values.yaml`:
```yaml
kafkaConnect:
  enabled: true
```
Then upgrade with that file, pinned to the chart version you upgrade to:
```shell
helm upgrade -n peaka <release> peaka/peaka --version <CHART_VERSION> -f values.yaml
```
Without `--version`, Helm skips pre-releases such as `1.1.0-beta.31` and picks the latest stable chart. Do not run
`helm upgrade` with only `--set kafkaConnect.enabled=true`: Helm then drops your previous values and uses the chart
defaults for everything else.

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
    each starting its new pod before it stops the old one. With the surge that is ≈ 37 GiB / 8.7 vCPU of
    requests and ≈ 172 GiB of limits by default, ≈ 168 GiB / 10.7 vCPU and ≈ 260 GiB in production;
  - LimitRange max ≥ the largest limit (24Gi, production 36Gi), min ≤ the smallest request (32Mi / 50m);
  - `maxLimitRequestRatio`: memory ≥ 16; CPU absent, or ≥ the default CPU limit / 50m;
  - a default CPU limit re-adds CPU limits: it must be ≥ 1 (Trino's CPU request), or the Trino pods are rejected
    (request > limit). Remove it only if no quota covers `limits.cpu` and no CPU `maxLimitRequestRatio` is set,
    since no container sets its own CPU limit; a `limits.cpu` quota needs one default per container, ≈ 82 × the
    default during the rollout (production ≈ 84 ×);
  - init containers and the Temporal schema Jobs set no resources, so with a quota on requests or limits the
    LimitRange must give them defaults.
- Production: you need ≥ 3 schedulable nodes, each with ≈ 45 GiB allocatable free for Peaka, and the node that
  runs the Trino coordinator ≈ 57 GiB (`kubectl describe nodes`). Trino workers use `Recreate`, so all old
  workers stop first; if a new one stays `Pending`, run `helm rollback`.

### Tainted nodes
`global.tolerations` does not reach every pod. Also set `temporal.server.tolerations`,
`temporal.admintools.tolerations` (schema Job), `pgcat.tolerations`, `kafka.controller.tolerations`,
`mongodb.tolerations`, `redis.master.tolerations`, `minio.tolerations`, `traefik.tolerations` and
`permify.tolerations`. The in-chart Postgres has no tolerations setting: on tainted-only nodes use
`externalPostgresql`.

### Query admission control (optional)
`trino.resourceGroups.enabled: true` caps how many Trino queries run at once (Trino resource groups); queries over
a cap wait in a queue. Without it, a burst of queries can fill the coordinator and nothing finishes until it drains.
- Groups: `health` (the healthcheck), `system` (Peaka's own maintenance users `trino` and `code2db`), `tenants`
  (project users, with a cap per project) and `other` (any other user, e.g. a person connecting directly).
- Size `trino.resourceGroups.limits` per install: `running` is the cap, `queued` how many may wait; a query that
  arrives when its group's queue is full fails with `QUERY_QUEUE_FULL`. Start from the defaults, then look at
  `system.runtime.queries` (columns `state`, `resource_group_id`) on a busy day: raise a cap whose group queues
  often while the cluster has CPU and memory free; lower `global` if the coordinator still stalls.
- Turning it on or changing a number restarts the Trino coordinator, which fails the queries running at that
  moment: do it in a quiet hour.
- Do not also put `resource-groups.properties` or `resource-groups.json` in `trino.coordinator.additionalConfigFiles`;
  the chart refuses to render if you do.

## Known Limitations
- If you are accessing Peaka from a hostname which is not localhost, then you need to enable TLS to access Peaka studio 
web application. If TLS is terminated before the traffic reaches Peaka app, then TLS of this chart
should be disabled by setting `tls.enabled` to false in `values.yaml`. If you plan to have Peaka terminate TLS, then set 
`tls.enabled` to true and enter certificate details in `tls.cert` and `tls.key` in `values.yaml`. 
