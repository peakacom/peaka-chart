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

{{- define "peaka.validate.logging" }}
{{- $fb := .Values.logging.fluentBit -}}
{{- if $fb.enabled -}}
{{- $enabled := 0 -}}
{{- range $name, $output := $fb.outputs -}}
{{- if ne $name "openobserve" -}}
{{- fail (printf "logging.fluentBit.outputs.%s is not a supported output (supported: openobserve)." $name) }}
{{- end -}}
{{- if $output.enabled -}}{{- $enabled = add1 $enabled -}}{{- end -}}
{{- end -}}
{{- if eq $enabled 0 -}}
{{- fail "logging.fluentBit.enabled is true but no logging.fluentBit.outputs.* output is enabled." }}
{{- end -}}
{{- if and $fb.outputs.openobserve.enabled (not .Values.logging.openobserve.enabled) -}}
{{- fail "logging.fluentBit.outputs.openobserve.enabled requires logging.openobserve.enabled (or disable that output)." }}
{{- end -}}
{{- end -}}
{{- if .Values.logging.openobserve.enabled -}}
{{- $days := int .Values.logging.openobserve.retentionDays -}}
{{- if and (gt $days 0) (lt $days 3) -}}
{{- fail "logging.openobserve.retentionDays must be at least 3: OpenObserve does not start with 1 or 2." }}
{{- end -}}
{{- end -}}
{{- end }}
