# MongoDB

A document database. In this chart it's used by **`be-collab-sharedb`** for real-time collaborative editing state — operational transforms (OT) require a fast, mutable document store that can handle bursty writes.

## How this project uses MongoDB

- Bitnami chart `14.8.0`, `bitnamilegacy/mongodb`.
- **Standalone**, single replica (`architecture: standalone`).
- **No auth** by default (`auth.enabled: false`). On-prem-friendly default but obviously a security concern in production.
- 4Gi PVC.

## Connection URL builder

`_helpers.tpl#peaka.mongodb.url` (line 864) is the most-iterated helper in the chart — six different commits in two months. It constructs the URL like:

```
mongodb[+srv]://[user:pass@]host[:port][?tls=true&retryWrites=false&...]
```

with branches for:
- External MongoDB connection (`externalMongoDB.enabled`)
- `mongodb+srv://` SRV records (skips port)
- TLS (only meaningful without SRV)
- `additionalParameters: []` to append arbitrary query params
- A `connection_uri:` field that **overrides everything** if set.

**Don't simplify this template.** Each branch was added in response to a real customer who needed it.

## Where the URL flows

The env var `SHAREDB_MONGO` is set from `peaka.mongodb.url`. Only `be-collab-sharedb` reads it.

## Files

- Subchart values: `chart/values.yaml#mongodb`
- External-mode values: `chart/values.yaml#externalMongoDB`
- Helper: `_helpers.tpl#peaka.mongodb.*`

## Pitfalls

- The default no-auth setup is fine for evaluation but **must be locked down** in production. Either set `mongodb.auth.enabled: true` and pass creds, or use `externalMongoDB` against a managed Atlas cluster.
- `mongodb.enabled` and `externalMongoDB.enabled` are mutually exclusive (validated).
- The `connection_uri` field bypasses **all** other Mongo URL logic. If a customer reports "TLS isn't working", check whether they set `connection_uri:` — that was the trap behind commit `c3c195f` "Change the mongo uri form".
