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
