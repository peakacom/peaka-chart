{{/*
!!! GOTCHA — see docs/extras/gotchas_invariants.md (#1, #2)
This file IS the in-cluster-vs-external XOR enforcement (postgres, minio,
mongo) AND the hiveMetastore ↔ mariadb coupling check. Every `fail` clause
below corresponds to a numbered invariant in the gotchas doc. When adding
a new mutual-exclusion or cross-key rule:
  1. Add the `fail` here so render fails fast,
  2. Mirror it in docs/extras/gotchas_invariants.md with a new number,
  3. Add a matching check_* function to scripts/validate.sh.
The three surfaces must stay in sync — drift here is invisible until a
customer install breaks.
*/}}
{{- define  "peaka.validate.postgresql" }}
{{- if and (not .Values.postgresql.enabled) (not .Values.externalPostgresql.enabled) }}
{{- fail "You must enable either postgresql.enabled or externalPostgresql.enabled." }}
{{- end }}

{{- if and .Values.postgresql.enabled .Values.externalPostgresql.enabled }}
{{- fail "You cannot enable both postgresql.enabled and externalPostgresql.enabled at the same time." }}
{{- end }}
{{- end }}

{{- define "peaka.validate.objectStore" }}
{{/*
minio.enabled and externalObjectStore.enabled may both be true: every client
(env-configmap, trino catalog, hive metastore) deterministically follows
externalObjectStore when it is enabled, while the in-cluster MinIO server can
stay deployed (e.g. migration staging buckets still living there).
*/}}
{{- if and (not .Values.minio.enabled) (not .Values.externalObjectStore.enabled) -}}
{{- fail "You must enable either minio.enabled or externalObjectStore.enabled." }}
{{- end }}

{{- if .Values.externalObjectStore.enabled -}}
{{- if not .Values.externalObjectStore.accessKey -}}
{{- fail "externalObjectStore.accessKey must not be empty when externalObjectStore.enabled is true." }}
{{- end }}
{{- if not .Values.externalObjectStore.secretKey -}}
{{- fail "externalObjectStore.secretKey must not be empty when externalObjectStore.enabled is true." }}
{{- end }}
{{- end }}
{{- end }}

{{- define "peaka.validate.mongodb" }}
{{- if and .Values.mongodb.enabled .Values.externalMongoDB.enabled -}}
{{- fail "You cannot enable both mongodb.enabled and externalMongoDB.enabled at the same time." }}
{{- end }}

{{- if and (not .Values.mongodb.enabled) (not .Values.externalMongoDB.enabled) -}}
{{- fail "You must enable either mongodb.enabled or externalMongoDB.enabled." }}
{{- end -}}
{{- end }}
