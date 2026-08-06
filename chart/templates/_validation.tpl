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
Three Kubernetes limits bind on peaka.fullname, all against the 63-character cap
on DNS labels and label values. Neither `helm template` nor `helm lint` checks
any of them, so without this guard an over-long release name or fullnameOverride
renders cleanly and fails only at apply time (or, worse, installs and leaves a
StatefulSet whose pods cannot resolve), with an error that does not name the
cause.

  1. Label VALUES are capped at 63. Longest suffix appended to fullname is
     `-be-collab-sharedb-websocket` (28)                    -> fullname <= 35
  2. Service names are RFC 1035 labels, also capped at 63, same suffix (28)
                                                            -> fullname <= 35
  3. StatefulSet pods are named `<sts-name>-<ordinal>`, and that pod name is a
     DNS label in the headless-service record, so it must fit 63 - NOT the 253
     that applies to most object names. Longest StatefulSet suffix is
     `-be-workflow-worker-express` (27); reserve 3 for a `-NN` ordinal so
     scaling past 9 replicas stays safe          -> fullname <= 63-27-3 = 33

(3) binds, so 33 is the limit enforced here. If a longer service or StatefulSet
name is ever added, recompute: the check is only as good as these measurements.
*/}}
{{- define "peaka.validate.nameLength" }}
{{- $fullname := include "peaka.fullname" . }}
{{- $limit := 33 }}
{{- if gt (len $fullname) $limit }}
{{- fail (printf "Name too long: %q is %d characters, but the limit is %d. Peaka appends suffixes of up to 28 characters to this name for Service names and label values, and StatefulSet pods append a further \"-<ordinal>\" that must still fit a 63-character DNS label. Past %d characters those exceed Kubernetes' limits, which fails at apply time rather than here. Use a shorter release name, or set fullnameOverride to at most %d characters." $fullname (len $fullname) $limit $limit $limit) }}
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
