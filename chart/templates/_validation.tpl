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

{{- define  "peaka.validate.metastore" }}
{{- if and (eq .Values.hiveMetastore.metastoreType "postgres") .Values.mariadb.enabled }}
{{- fail "You set hiveMetastore.metastoreType to \"postgres\". Set mariadb.enabled to false if you want to use PostgreSQL as your metastore." }}
{{- end }}

{{- if and (eq .Values.hiveMetastore.metastoreType "mysql") (not .Values.mariadb.enabled) }}
{{- fail "You set hiveMetastore.metastoreType to \"mysql\" but mariadb.enabled is false. Enable mariadb to use MySQL as your metastore." }}
{{- end }}
{{- end }}

{{- define "peaka.validate.objectStore" }}
{{- if and .Values.minio.enabled .Values.externalObjectStore.enabled -}}
{{- fail "You cannot enable both minio.enabled and externalObjectStore.enabled at the same time." }}
{{- end }}

{{- if and (not .Values.minio.enabled) (not .Values.externalObjectStore.enabled) -}}
{{- fail "You must enable either minio.enabled or externalObjectStore.enabled." }}
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
