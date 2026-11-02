# Overall system: tools, environments, services, infrastructure

How everything fits together — from `git tag` to "customer's pod is serving traffic".

```mermaid
flowchart LR
    subgraph dev["Developer machine"]
        edit["Edit chart/values.yaml + Chart.yaml"]
        push["git push --tags"]
    end

    subgraph ci["Drone CI (kubernetes runner)"]
        vc["version-check<br/>tag == Chart.yaml#version"]
        pkg["helm-package<br/>peaka-X.Y.Z.tgz"]
        idx["update-index-file"]
        push2["push to GCS"]
        sig["HMAC-signed pipeline<br/>(.drone.yml#kind: signature)"]
    end

    subgraph dist["Distribution"]
        gcs[("gs://peaka-chart/charts/<br/>(public read)")]
        gar[("europe-west3-docker.pkg.dev/<br/>code2-324814/...<br/>(private GAR)")]
    end

    subgraph cust["Customer Kubernetes cluster"]
        helm["helm install peaka/peaka<br/>-f values.yaml"]
        traefik["Traefik IngressRoute CRDs<br/>web:80, websecure:443, dbc:4567"]
        subgraph ns["namespace = peaka"]
            edge[Studio Web - SPA via nginx]
            api[~25 backend services]
            data["Data plane:<br/>Postgres x2, Mongo, Redis,<br/>MinIO, Kafka, MariaDB"]
            wf["Workflow plane:<br/>Temporal + 4 workflow services"]
            query["Query plane:<br/>Trino + Hive metastore"]
            authz[Permify + PgCat]
        end
    end

    edit --> push --> vc --> pkg --> idx --> push2 --> gcs
    sig -.protects.-> ci
    helm -->|pulls chart| gcs
    helm -->|pulls images| gar
    helm -->|renders + applies| ns
    helm -->|installs CRDs separately| traefik
    traefik --> edge
    traefik --> api
    traefik -->|forwardAuth middleware| authz
    api --> data
    api --> wf
    api --> query
    wf --> data
    query --> data
```

## Reading this diagram

- **Left third**: how new chart versions get built and published. Single source of truth = git tag.
- **Middle**: artifacts (chart .tgz in GCS, container images in GAR).
- **Right**: what runs at the customer. Three planes (data, workflow, query) plus the edge.
- **Trust boundary**: between the customer cluster and Peaka's CI is the GAR auth secret + the GCS bucket URL. Nothing else crosses.

## Annotations

- **Drone HMAC signature** is a tamper-evidence on the pipeline definition itself (not on artifacts).
- **`helm install` requires Traefik CRDs to be applied first** (separate `kubectl apply`). The chart cannot install them itself in a default install.
- **Each customer's `values.yaml` is private to them.** Peaka does not see customer values.
