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
Define the peaka.namespace template if set with global.namespace or .Release.Namespace is set
*/}}
{{- define "peaka.namespace" -}}
  {{- default .Release.Namespace .Values.global.namespace -}}
{{- end }}

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
{{- default "console" (quote .Values.hiveMetastore.minioAccessKey) }}
{{- end }}

{{/*
Set minio secretKey
*/}}
{{- define "peaka.minio.secretKey" }}
{{- default "console123" (quote .Values.hiveMetastore.minioSecretKey) }}
{{- end }}

{{/*
Define the peaka.mariadb.fullname template with .Release.Name and "minio"
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
