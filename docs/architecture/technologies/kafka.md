# Kafka + Kafka Connect

**Kafka** is a distributed event streaming platform. **Kafka Connect** is a framework for moving data between Kafka and external systems via reusable connectors.

## How this project uses Kafka

Bitnami chart `26.8.5`, `bitnamilegacy/kafka`. Configured for KRaft mode (no ZooKeeper):

- `controller.replicaCount: 1` — single broker, KRaft controller.
- `provisioning.numPartitions: 20`, `replicationFactor: 1`.
- `extraConfig`: `log.retention.hours=12`, `max.message.bytes=50000000` (50MB), `delete.topic.enable=true`.
- All listeners `PLAINTEXT`. **Not encrypted in transit.**

Used as an event bus by Peaka services for change events, task queues, and pipeline coordination. The bootstrap address is exposed as `BOOTSTRAP_ADDRESS` in the shared env ConfigMap.

## Two Kafka Connect deployments

There are **two separate Connect clusters** in the chart — easy source of confusion.

### `kafkaConnect` (the upstream-facing one)
- Image: `quay.io/debezium/connect:3.1`
- Avro converter (`io.confluent.connect.avro.AvroConverter`)
- Used for **CDC connectors** — Debezium reading from Postgres/MySQL/Mongo source databases that customer connectors target.
- Schema registry expected but `cp-schema-registry.url: ""` is empty by default. **You probably need to wire one up for Avro to work properly.**

### `monitoringKafkaConnect` (Peaka-internal)
- Image: `code2io/peaka-kafka-connect:v1.0.1` — Peaka's custom build
- JSON converter (no schema registry needed)
- Larger heap: `-Xms512M -Xmx4096M`
- Used for **monitoring pipelines** — Peaka's own change events flowing to internal sinks
- JMX/Prometheus exporters wired but disabled by default

## Files

- Subchart values: `chart/values.yaml#kafka`
- Standalone Connect templates: `chart/templates/kafka-connect/`, `chart/templates/monitoring-kafka-connect/`
- Helpers: `_helpers.tpl#peaka.kafka.*`, `peaka.kafka-connect.*`, `peaka.monitoring-kafka-connect.*`

## Pitfalls

- **PLAINTEXT only.** No way to enable TLS in the current chart without forking subchart values.
- Single-broker default → no HA. `replicationFactor: 1` for all topics.
- 12-hour retention is short. If a downstream consumer goes down for a weekend, it'll miss events. Adjust `extraConfig.log.retention.hours` for production.
- The `kafkaConnect` Avro converter without a schema registry will silently fall back to JSON-encoded Avro records that nothing will deserialize correctly. Either wire `cp-schema-registry.url` to a real registry or switch the converter to JSON.
- `monitoringKafkaConnect.kafka.bootstrapServers: ""` — empty. Worth verifying it's actually set somewhere at runtime; otherwise this Connect cluster has no Kafka to talk to.
