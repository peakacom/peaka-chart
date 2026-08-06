{{- define  "peaka.validate.postgresql" }}
{{- if and (not .Values.postgresql.enabled) (not .Values.externalPostgresql.enabled) }}
{{- fail "You must enable either postgresql.enabled or externalPostgresql.enabled." }}
{{- end }}

{{- if and .Values.postgresql.enabled .Values.externalPostgresql.enabled }}
{{- fail "You cannot enable both postgresql.enabled and externalPostgresql.enabled at the same time." }}
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

{{/*
Kubernetes caps label VALUES at 63 characters. Services label their resources
`app.kubernetes.io/name: <peaka.fullname>-be-<service>`, and the longest suffix
in use is `-be-collab-sharedb-websocket` (28 chars), so peaka.fullname must stay
within 63-28=35 characters. Neither `helm template` nor `helm lint` checks label
length, so without this guard an over-long release name or fullnameOverride
renders fine and is only rejected by the API server at apply time, with an error
that does not name the cause.
*/}}
{{- define "peaka.validate.nameLength" }}
{{- $fullname := include "peaka.fullname" . }}
{{- $longestSuffix := 28 }}
{{- if gt (add (len $fullname) $longestSuffix) 63 }}
{{- fail (printf "Name too long: %q is %d characters. Appending the longest resource suffix (-be-collab-sharedb-websocket, %d characters) exceeds Kubernetes' 63-character limit for label values, which the API server rejects at apply time. Use a release name (or fullnameOverride) of at most %d characters." $fullname (len $fullname) $longestSuffix (sub 63 $longestSuffix)) }}
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
