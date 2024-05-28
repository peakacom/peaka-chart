{{/*
Expand the name of the chart.
*/}}
{{- define "peaka.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "peaka.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "peaka.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "peaka.labels" -}}
helm.sh/chart: {{ include "peaka.chart" . }}
{{ include "peaka.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "peaka.selectorLabels" -}}
app.kubernetes.io/name: {{ include "peaka.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "peaka.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "peaka.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Set image registry for peaka images
*/}}
{{- define "peaka.image.registry" -}}
europe-west3-docker.pkg.dev/code2-324814/peaka-service-container-images
{{- end -}}

{{- define "peaka.postgresql.fullname" -}}
{{- printf "%s-%s" .Release.Name "postgresql" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "peaka.postgresql.port" -}}
{{- default 5432 .Values.postgresql.primary.service.ports.postgresql -}}
{{- end -}}

{{- define "peaka.postgresql.user" -}}
{{- .Values.postgresql.auth.username -}}
{{- end -}}

{{- define "peaka.postgresql.database" -}}
{{- .Values.postgresql.auth.database -}}
{{- end -}}

{{- define "peaka.postgresql.password" -}}
{{- .Values.postgresql.auth.password -}}
{{- end -}}

{{- define "peaka.hive.name" -}}
{{ include "peaka.fullname" . }}-hive-metastore
{{- end -}}

{{- define "peaka.hive.port" -}}
{{ default 9083 .Values.hiveMetastore.servicePort }}
{{- end -}}

{{/*
Define the peaka.minio.fullname template with .Release.Name and "minio"
*/}}
{{- define "peaka.minio.fullname" -}}
{{- printf "%s-%s" .Release.Name "minio" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Set minio port
*/}}
{{- define "peaka.minio.port" }}
{{- default 9000 .Values.minio.service.port }}
{{- end }}

{{/*
Set minio accessKey
*/}}
{{- define "peaka.minio.accessKey" }}
{{- default "console" .Values.hiveMetastore.minioAccessKey }}
{{- end }}

{{/*
Set minio secretKey
*/}}
{{- define "peaka.minio.secretKey" }}
{{- default "console123" .Values.hiveMetastore.minioSecretKey }}
{{- end }}

{{/*
Define the peaka.mariadb.fullname template with .Release.Name and "mariadb"
*/}}
{{- define "peaka.mariadb.fullname" -}}
{{- printf "%s-%s" .Release.Name "mariadb" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Set mariadb user
*/}}
{{- define "peaka.mariadb.user" }}
{{- default "peaka" (quote .Values.mariadb.db.user) }}
{{- end }}

{{/*
Set mariadb password
*/}}
{{- define "peaka.mariadb.password" }}
{{- default "peaka" (quote .Values.mariadb.db.password) }}
{{- end }}

{{/*
Set mariadb db name
*/}}
{{- define "peaka.mariadb.dbName" }}
{{- default "metastore_db" (quote .Values.mariadb.db.name) }}
{{- end }}

{{/*
Set mariadb port
*/}}
{{- define "peaka.mariadb.port" }}
{{- default 3306 (quote .Values.mariadb.service.ports.mysql) }}
{{- end }}

{{/*
Define the peaka.kafka.fullname template with .Release.Name and "kafka"
*/}}
{{- define "peaka.kafka.fullname" -}}
{{- printf "%s-%s" .Release.Name "kafka" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Set kafka port
*/}}
{{- define "peaka.kafka.port" }}
{{- default 9092 (quote .Values.kafka.service.ports.client) }}
{{- end }}

{{/*
Define the peaka.mongodb.fullname template with .Release.Name and "mongodb"
*/}}
{{- define "peaka.mongodb.fullname" -}}
{{- printf "%s-%s" .Release.Name "mongodb" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Define the peaka.redis.fullname template with .Release.Name and "redis"
*/}}
{{- define "peaka.redis.fullname" -}}
{{- printf "%s-%s" .Release.Name "redis" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Define the peaka.bigtable.fullname template with .Release.Name and "bigtable"
*/}}
{{- define "peaka.bigtable.fullname" -}}
{{- printf "%s-%s" .Release.Name "bigtable" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "peaka.bigtable.port" -}}
{{- default 5432 .Values.postgresqlBigtable.primary.service.ports.postgresql -}}
{{- end -}}

{{- define "peaka.bigtable.user" -}}
{{- .Values.postgresqlBigtable.auth.username -}}
{{- end -}}

{{- define "peaka.bigtable.database" -}}
{{- .Values.postgresqlBigtable.auth.database -}}
{{- end -}}

{{- define "peaka.bigtable.password" -}}
{{- .Values.postgresqlBigtable.auth.password -}}
{{- end -}}

{{/*
Define the peaka.kafka-connect.fullname template with .Release.Name and "kafka-connect"
*/}}
{{- define "peaka.kafka-connect.fullname" -}}
{{- printf "%s-%s" .Release.Name "kafka-connect" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified kafka headless name.
*/}}
{{- define "peaka.kafka-connect.kafka-headless.fullname" -}}
{{- $name := "kafka-headless" -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Set peaka.kafka-connect.groupId to Release Name
*/}}
{{- define "peaka.kafka-connect.groupId" -}}
{{- .Release.Name -}}
{{- end -}}

{{/*
Create a default fully qualified schema registry name for kafka connect.
*/}}
{{- define "peaka.kafka-connect.cp-schema-registry.fullname" -}}
{{- printf "%s-%s" .Release.Name "kafka-connect-schema-registry" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "peaka.kafka-connect.cp-schema-registry.service-name" -}}
{{- if (index .Values "kafkaConnect" "cp-schema-registry" "url") -}}
{{- printf "%s" (index .Values "kafkaConnect" "cp-schema-registry" "url") -}}
{{- else -}}
{{- printf "http://%s:8081" (include "peaka.kafka-connect.cp-schema-registry.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "peaka.trino.fullname" -}}
{{- printf "%s-%s" .Release.Name "trino" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "peaka.trino.catalog" -}}
{{ template "peaka.trino.fullname" . }}-catalog
{{- end -}}

{{- define "peaka.trino.worker" -}}
{{- printf "%s-%s" .Release.Name "trino-worker" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "peaka.trino.coordinator" -}}
{{- printf "%s-%s" .Release.Name "trino-coordinator" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Create the name of the trino service account to use
*/}}
{{- define "peaka.trino.serviceAccountName" -}}
{{- if .Values.trino.serviceAccount.create }}
{{- default (include "peaka.trino.fullname" .) .Values.trino.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.trino.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Common labels of trino
*/}}
{{- define "peaka.trino.labels" -}}
helm.sh/chart: {{ include "peaka.chart" . }}
{{ include "peaka.trino.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels for trino
*/}}
{{- define "peaka.trino.selectorLabels" -}}
app.kubernetes.io/name: {{ include "peaka.trino.fullname" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
