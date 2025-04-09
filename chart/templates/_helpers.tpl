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
Return  the proper Storage Class
{{ include "peaka.common.storage.class" ( dict "persistence" .Values.path.to.the.persistence "global" $.Values.global) }}
*/}}
{{- define "peaka.common.storage.class" -}}

  {{- $storageClass := .persistence.storageClass -}}
  {{- if .global -}}
      {{- if .global.storageClass -}}
          {{- $storageClass = .global.storageClass -}}
      {{- end -}}
  {{- end -}}

  {{- if $storageClass -}}
    {{- if (eq "-" $storageClass) -}}
        {{- printf "storageClassName: \"\"" -}}
    {{- else }}
        {{- printf "storageClassName: %s" $storageClass -}}
    {{- end -}}
  {{- end -}}

{{- end -}}

{{/*
Environment variables injected into Peaka services
*/}}
{{- define "peaka.common.envVars" -}}
MINIO_ADDRESS: http://{{ include "peaka.minio.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:{{ include "peaka.minio.port" . }}
MINIO_ACCESS_KEY: {{ include "peaka.minio.accessKey" . | quote }}
MINIO_SECRET_KEY: {{ include "peaka.minio.secretKey" .  | quote }}

STUDIO_DB_ADDRESS: jdbc:postgresql://{{ include "peaka.postgresql.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:{{ include "peaka.postgresql.port" . }}/{{ include "peaka.postgresql.database" . }}
DB_USERNAME: {{ include "peaka.postgresql.user" . | quote }}
DB_PASSWORD: {{ include "peaka.postgresql.password" . | quote }}

SECRET_STORAGE_SERVICE: http://{{ include "peaka.fullname" . }}-be-secret-store-service.{{ .Release.Namespace }}.svc.cluster.local:80

AUTH_SERVICE_EXTERNAL_ADDRESS: {{ include "peaka.routes.baseServiceUrl" . }}/auth
FETCH_METADATA_URL: {{ include "peaka.routes.baseServiceUrl" . }}/runtimeapi
REACT_APP_FETCH_METADATA_URL: {{ include "peaka.routes.baseServiceUrl" . }}/runtimeapi
DISPATCHER_HOST_NAME: {{ include "peaka.routes.baseServiceUrlNoScheme" . }}/dispatcher
API_HOST_NAME_PATTERN: "{{ include "peaka.routes.baseUrlNoScheme" . }}/{{ include "peaka.routes.apiPath" . }}/.*"
STUDIO_HOST: {{ include "peaka.routes.baseUrl" . }}
STUDIO_API_HOST: {{ include "peaka.routes.baseServiceUrl" . }}/studioapi
CODE2_DOMAIN: {{ .Values.accessUrl.domain }}
DISPATCHER_URL: {{ include "peaka.routes.baseServiceUrl" . }}/dispatcher
COLLABORATION_BACKEND_ADDRESS: {{ include "peaka.websocketScheme" . }}://{{ include "peaka.routes.baseServiceUrlNoScheme" . }}/sharedb
STUDIO_API_URL: {{ include "peaka.routes.baseServiceUrl" . }}/studioapi/api
TOKEN_SERVICE_PUBLIC_URL: {{ include "peaka.routes.baseServiceUrl" . }}/token-service
TOKEN_SERVICE_REDIRECT_URL: {{ include "peaka.routes.baseUrl" . }}/oauth2/callback
DBC_PUBLIC_URL: {{ include "peaka.dbc.url" . }}
STUDIO_API_HOST_NO_SCHEME: {{ .Values.accessUrl.domain }}

ENVIRONMENT: production
TEST_ENVIRONMENT: "false"
CLUSTER_NAMESPACE: prod

ZONE: onprem

LOGIN_BETA_CLOSED: "false"
ENVIRONMENT_SCOPE: STABLE
USER_ACTIVATION: DEFAULT_ACTIVE
ENABLE_TABLE_ACTIVE: "true"
HUBSPOT_ENABLED: "false"

REDIS_SINGLE_SERVER_ADDRESS: redis://{{ include "peaka.redis-master.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:6379
REDIS_SINGLE_SERVER_HOST_NAME: {{ include "peaka.redis-master.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local

BOOTSTRAP_ADDRESS: {{ include "peaka.kafka.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:{{ include "peaka.kafka.port" . }}
KAFKA_CONNECT_ADDRESS: http://{{ include "peaka.kafka-connect.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:8083

TEMPORAL_TARGET: {{ include "peaka.temporal.frontend.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:7233

DB_HOST: {{ include "peaka.postgresql.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local
STUDIODB_SCHEMA: studio

DB_PORT: {{ include "peaka.postgresql.port" . | quote }}
DB_NAME: {{ include "peaka.postgresql.database" . }}

TRINO_ADDRESS: jdbc:trino://{{ include "peaka.trino.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:8080
TRINO_PASSWORD: {{ .Values.trino.password }}
TRINO_USERNAME: {{ .Values.trino.username }}
TRINO_JDBC_URL: jdbc:trino://{{ include "peaka.trino.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:8080/?user=trino

TOKEN_SERVICE_INTERNAL_ADDRESS: http://{{ include "peaka.fullname" . }}-be-token-service.{{ .Release.Namespace }}.svc.cluster.local:80
AUTH_SERVICE_INTERNAL_ADDRESS: http://{{ include "peaka.fullname" . }}-be-auth-service.{{ .Release.Namespace }}.svc.cluster.local:80
DATA_REST_INTERNAL_ADDRESS: http://{{ include "peaka.fullname" . }}-be-data-rest.{{ .Release.Namespace }}.svc.cluster.local:80
EMAIL_SERVICE_INTERNAL_URL: http://{{ include "peaka.fullname" . }}-be-email-service.{{ .Release.Namespace }}.svc.cluster.local:80
PERMISSIONS_SERVICE_ADDRESS: http://{{ include "peaka.fullname" . }}-be-permission-service.{{ .Release.Namespace }}.svc.cluster.local:80
STUDIO_API_SERVICE_ADDRESS: http://{{ include "peaka.fullname" . }}-be-studio-api.{{ .Release.Namespace }}.svc.cluster.local:80
METADATA_SERVICE_URL: http://{{ include "peaka.fullname" . }}-be-metadata-service.{{ .Release.Namespace }}.svc.cluster.local:80
METADATA_SERVICE_HOST: {{ include "peaka.fullname" . }}-be-metadata-service.{{ .Release.Namespace }}.svc.cluster.local
STUDIO_API_SERVICE_HOST_NAME: {{ include "peaka.fullname" . }}-be-studio-api.{{ .Release.Namespace }}.svc.cluster.local
SHAREDB_URL: http://{{ include "peaka.fullname" . }}-be-collab-sharedb-http.{{ .Release.Namespace }}.svc.cluster.local:80
SCHEDULEDFLOWRUNNER_URL: http://{{ include "peaka.fullname" . }}-be-scheduled-flow-runner.{{ .Release.Namespace }}.svc.cluster.local:80
ACTION_SERVICE_URL: http://{{ include "peaka.fullname" . }}-be-workflow-worker-express.{{ .Release.Namespace }}.svc.cluster.local:80/express-worker/action/execute
DATA_CACHE_SERVICE_URL: http://{{ include "peaka.fullname" . }}-be-data-cache.{{ .Release.Namespace }}.svc.cluster.local:80
MONITORING_SERVICE_INTERNAL_URL: http://{{ include "peaka.fullname" . }}-be-monitoring-service.{{ .Release.Namespace }}.svc.cluster.local:80
EXPRESS_WORKFLOW_WORKER_BASE_URL: http://{{ include "peaka.fullname" . }}-be-workflow-worker-express.{{ .Release.Namespace }}.svc.cluster.local:80

JEXL_ADDRESS: localhost:8080
SIDECAR_PORT: "8080"


CODE2_DEFAULT_SENDER: "info@peaka.com"
CODE2_DEFAULT_EMAIL_SERVICE_PROVIDER: {{ default "sendgrid" .Values.emailServiceProvider }}
DEFAULT_SMTP_SERVER_HOST: {{ default "localhost" .Values.smtpServerHost }}
DEFAULT_SMTP_SERVER_PORT: {{ default "25" .Values.smtpServerPort | quote }}
DEFAULT_SMTP_SERVER_USERNAME: {{ default "default" .Values.smtpServerUsername }}
DEFAULT_SMTP_SERVER_PASSWORD: {{ default "default" .Values.smtpServerPassword }}
DEFAULT_SMTP_TLS_ENABLED: {{ default false .Values.smtpTlsEnabled | quote }}

SECRET_STORE_SECRET_KEY: {{ .Values.secretStoreService.secretEncryptionKey }}
JWT_RSA_PRIVATE_KEY_PATH: /secrets/jwt/rsa/privatekey.pem
JWT_RSA_PUBLIC_KEY_PATH: /secrets/jwt/rsa/publickey.pem
PUBLIC_CERT: /secrets/jwt/rsa/publickey.pem

MONGODB_ARCHITECTURE: {{ .Values.mongodb.architecture }}
SHAREDB_MONGO: mongodb://{{ include "peaka.mongodb.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local


APP_BASEDIR: /metadata-nfs
GITHUB_ENABLED: "false"
CONNECTOR_BASEDIR: /run/resource/connector


SAMPLE_DATA_APP_ID: {{ .Values.sampleDataAppId }}

BIGTABLE_BUFFER_DB_HOST: {{ include "peaka.bigtable.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local
BIGTABLE_BUFFER_DB_PORT: {{ include "peaka.bigtable.port" . | quote }}
BIGTABLE_BUFFER_DB_USERNAME: {{ include "peaka.bigtable.user" . }}
BIGTABLE_BUFFER_DB_PASSWORD: {{ include "peaka.bigtable.password" . }}
BIGTABLE_BUFFER_DB_NAME: {{ include "peaka.bigtable.database" .  }}

PAYMENT_ENABLED: "false"
USAGE_MONITORING_ENABLED: "false"
SOCIAL_LOGIN_ENABLED: "false"
CODE2_ENVIRONMENT: prod

DBC_PUBLIC_PORT: {{ include "peaka.dbc.port" . | quote }}
DBC_SCHEME: {{ include "peaka.httpScheme" . | quote }}
ONPREMISE: "true"

STUDIO_API_PORT: {{ .Values.accessUrl.port | quote }}
STUDIO_API_SCHEME: {{ include "peaka.httpScheme" . | quote }}
STUDIO_API_PATH: /service/studioapi/data

ZIPY_ENABLED: "false"
GA_ENABLED: "false"
POSTHOG_ENABLED: "false"
MIXPANEL_ENABLED: "false"
OPENAI_API_KEY: {{ default "" .Values.openAIApiKey | quote }}
CODE2_PUBLISHED_APPS_DOMAIN: {{  .Values.accessUrl.domain | quote }}
CODE2_PREVIEWED_APPS_DOMAIN: {{  .Values.accessUrl.domain | quote }}

GRPC_DNS_RESOLVER: native

PERMIFY_URL: http://{{ include "peaka.permify.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:{{ .Values.permify.app.server.http.port }}
{{- end -}}

{{/*
Set image registry for peaka images
*/}}
{{- define "peaka.image.registry" -}}
europe-west3-docker.pkg.dev/code2-324814/peaka-service-container-images
{{- end -}}

{{/*
Create imagePullSecret to pull Peaka images
*/}}
{{- define "peaka.imageRegistry.secret" -}}
{{- $registry := "https://europe-west3-docker.pkg.dev" -}}
{{- $username := "_json_key" -}}
{{- $email := "not@val.id" -}}
{{- $password := .Values.imagePullSecret.gcpRegistryAuth.password | required ".Values.imagePullSecret.gcpRegistryAuth.password is required." -}}
{{- $auth := printf "%s:%s" $username $password | b64enc -}}
{{- $config := dict "auths" (dict $registry (dict "username" $username "password" $password "email" $email "auth" $auth)) -}}
{{- $config | toJson | b64enc -}}
{{- end -}}

{{/*
Set http scheme for Peaka
*/}}
{{- define "peaka.httpScheme" -}}
{{- .Values.accessUrl.scheme -}}
{{- end }}

{{/*
Set ws scheme for Peaka
*/}}
{{- define "peaka.websocketScheme" -}}
{{- if eq .Values.accessUrl.scheme "http"  -}}
{{- "ws" }}
{{- else }}
{{- "wss" }}
{{- end }}
{{- end }}

{{/*
Set Ingress route entry point based on TLS enabled
*/}}
{{- define "peaka.ingress.entryPoint" -}}
{{- if .Values.tls.enabled -}}
{{- "websecure" }}
{{- else }}
{{- "web" }}
{{- end }}
{{- end }}


{{- define "peaka.routes.baseUrl" -}}
{{- if .Values.accessUrl.port -}}
{{ include "peaka.httpScheme" . }}://{{ .Values.accessUrl.domain }}:{{ .Values.accessUrl.port }}
{{- else -}}
{{ include "peaka.httpScheme" . }}://{{ .Values.accessUrl.domain }}
{{- end -}}
{{- end -}}


{{- define "peaka.routes.baseUrlNoScheme" -}}
{{- if .Values.accessUrl.port -}}
{{ .Values.accessUrl.domain }}:{{ .Values.accessUrl.port }}
{{- else -}}
{{ .Values.accessUrl.domain }}
{{- end -}}
{{- end -}}


{{- define "peaka.routes.baseServiceUrl" -}}
{{ include  "peaka.routes.baseUrl" . }}/{{ include "peaka.routes.servicePath" . }}
{{- end -}}

{{- define "peaka.routes.baseServiceUrlNoScheme" -}}
{{ include  "peaka.routes.baseUrlNoScheme" . }}/{{ include "peaka.routes.servicePath" . }}
{{- end -}}


{{- define "peaka.routes.servicePath" -}}
service
{{- end -}}

{{- define "peaka.routes.apiPath" -}}
api
{{- end -}}

{{- define "peaka.routes.partnerPath" -}}
partner
{{- end -}}

{{- define "peaka.jwt.publicKey" -}}
LS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS0KTUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUExeG5BQTZaRDBoT1ZjMkMwY2ZyQwpWNzdPV01idGkzRFJ1cms0Y01jSGFGTGZuTGhNU1ZMRzdRZ3pFak5yU0hvREhKY1hCZWx4NXozaDMzWWxqWlJyClZUcTRBVU0yL3J1RWxldmdXdEplYWkydW9DcmlMcFh5MHhpb2JERlVYSHYveHk1c2VpYXY0aUNoeElBSkF0MmcKa1BhTTEwUittaDg4MmhlcStFTUFOZzdFME81M0s0WVFvc1VQSE9rZjdicW4wbWE3QTMrRVc5a3FPZXlvd2drNAp0dzUzR1lHdGJkVVlDNGFVbk1QdDYrN2M5U2hZZFRIMGRRWWNaMk8rWitnTzFOSDNGMm0wTDZvNXVOTzhZdm4wCkhobC90dHNaNUV6Z0lxZWFRM2pkWS9TK2c5NFRSZE0wUklWNHZTVXFmQUNqcmJyQmFONzQvWTlLWnIzMjZlMTAKYlFJREFRQUIKLS0tLS1FTkQgUFVCTElDIEtFWS0tLS0tCg==
{{- end -}}

{{- define "peaka.jwt.privateKey" -}}
LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0tCk1JSUV2UUlCQURBTkJna3Foa2lHOXcwQkFRRUZBQVNDQktjd2dnU2pBZ0VBQW9JQkFRRFhHY0FEcGtQU0U1VnoKWUxSeCtzSlh2czVZeHUyTGNORzZ1VGh3eHdkb1V0K2N1RXhKVXNidENETVNNMnRJZWdNY2x4Y0Y2WEhuUGVIZgpkaVdObEd0Vk9yZ0JRemIrdTRTVjYrQmEwbDVxTGE2Z0t1SXVsZkxUR0toc01WUmNlLy9ITG14NkpxL2lJS0hFCmdBa0MzYUNROW96WFJINmFIenphRjZyNFF3QTJEc1RRN25jcmhoQ2l4UThjNlIvdHVxZlNacnNEZjRSYjJTbzUKN0tqQ0NUaTNEbmNaZ2ExdDFSZ0xocFNjdyszcjd0ejFLRmgxTWZSMUJoeG5ZNzVuNkE3VTBmY1hhYlF2cWptNAowN3hpK2ZRZUdYKzIyeG5rVE9BaXA1cERlTjFqOUw2RDNoTkYwelJFaFhpOUpTcDhBS090dXNGbzN2ajlqMHBtCnZmYnA3WFJ0QWdNQkFBRUNnZ0VBSkxpaWFXMFZ5SFFyOEMvSzltZHBES3BJRjJ0VWk5alZrVE5FTWFxa3R0aHAKRU52OHVBclA1NURlQ1NZcWswdXpJc3NmZE5TcTY1K0tvMGZMOXV6bTJ2ekVnNENxVDVnTE5UMzR4Z0NDZWsxMApzYWJJaU12MEVibzBySTNLV1dTWTRMUHA5SHVNek1XbDRFSThaNWNXN1pDTnNFVmkrS1JMRXU5MThsNmIxMTVqCmJzRnRXRGRWRXp2SWVGbW56Y0ZiS2F3eG1iWnlpWWpGWDkrVitDUFRkY2h5ejkwMzFIdEpCeklBWUZmUm1jTHQKNmpQR1F3SkRBNXo2TklZWnh0dVJSRVExeGljNXRod0UrbURvaCtBVkx4TGpNVjQ5dlJST3ZRZ3d3WTk1TFRKawpTb2Vqb29icndhVGVtMkkyN1RtUk8rdm1US0ZhUndSaU4yWmdOL3Q4Z1FLQmdRRHhuSXIwdC9jNVgwNU5sYWw0CldKV2VKanhvSnNwbTlmcU1EUTFvWUh1SDJYWDJJQ3JFMzFxcXRzeUVJWVJmOTV4UVo0cHNaWVNBNDBwSkJEaHkKa2NFZmUvTEpZNXhzRzVHcnJqTjJQZ0RoZTl1LzF0SEpkdWFzNTExdXJLUUZzR1NTSEliMzVUWkIwbzZEbW9Mdgo1NG9EQXFKY3hqYktpUUl5T0l3U3JJbnM3UUtCZ1FEajZRbmdTS0QvQWE4UDB4WFk1TDBpNk9haEdFemlyM0ZPCkpxQmR3dEg0dm9aMFFhQkZ1dEJEOWxqZEZwVjY4RFY1ZVJnSXJkZks0QW4xSXhWZWhScmJTTUNuZGplZjhpVjkKL0t2UjBsWEh0aW5RWGRtUitYaUlOMEl3aVliSXFpUHEwLzQwUmlUZktwUU54RXNJZWpJckRFMkRLZk1nQTdoMApZUmVHSitBMWdRS0JnSEtqekdzQlB4VEIyKzJFTGIwa2l4bFhHeUp3QldtRkhUU0duTzRCbVp1RDJ5ekZab1d6ClZObmJrbjYvU0lnZ2ZOTEp6aXhRbnVabzhqNWkra1dpVXZnVlg4V2V0Z0cxc3hDNnYwQkRlemVDQldxcEN6R0UKY1Q5cEtEUHpSb0JNaWV1cURZQmlDYlNCcTQxV0t2cVo2aW96ZmNaM1psZ0RXajlxQlV4M0FacWhBb0dBQkh4dgp6MVJlcHVaWGxjNG4zZThTc2Y4M212QXBnMFRFekM4Q2RSWUNvQXpRQkxYTis5RmpqQkxyU043SzduS1ArdVloClRQcHZCdlZGL09kRjRtaG9VT3lycmlBcmxDQm1FSWJLc3dTYTM2VjhTVGV2c3FuZ2IzMzI5WkdmYjQrNXlVT0cKKzJ4dUNWNkRMNG92bCtrZjE2MFVVWUtmNEg5eVFBZ3hPRmpNbHdFQ2dZRUFrdk1ueFNoZ0U4dnp3Z1laZ3BvYgpIakhnTjA0ai9CNXpQZ0djdGNFYzlKR21xYlBidG9Cb1hsVFdHTURPOTlMenVnZHdIUGd6MXlkL0UvejJPamc3CnZHNTJDd1BnYUx4WWZzUzlKdFMva2FuNDVaSzNocFRoTTdYK1Rjc0ZkUzMxTVNlZFVvRnN6cjNwUVNMMVVmRVgKMEFnZjNLT3hPQ1BOSitjeEVTcXNZYTQ9Ci0tLS0tRU5EIFBSSVZBVEUgS0VZLS0tLS0K
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

{{- define "peaka.postgresql.passwordSecretKey" -}}
{{ .Values.postgresql.auth.secretKeys.userPasswordKey }}
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
{{- default "peaka"  .Values.mariadb.db.user }}
{{- end }}

{{/*
Set mariadb password
*/}}
{{- define "peaka.mariadb.password" }}
{{- default "peaka" .Values.mariadb.db.password }}
{{- end }}

{{/*
Set mariadb db name
*/}}
{{- define "peaka.mariadb.dbName" }}
{{- default "metastore_db"  .Values.mariadb.db.name }}
{{- end }}

{{/*
Set mariadb port
*/}}
{{- define "peaka.mariadb.port" }}
{{- default 3306  .Values.mariadb.service.ports.mysql }}
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
{{- default 9092 .Values.kafka.service.ports.client }}
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
Define the peaka.redis-master.fullname template with .Release.Name and "redis-master"
*/}}
{{- define "peaka.redis-master.fullname" -}}
{{- printf "%s-%s" .Release.Name "redis-master" | trunc 63 | trimSuffix "-" -}}
{{- end -}}



{{/*
Define the peaka.bigtable.fullname template with .Release.Name and "bigtable"
*/}}
{{- define "peaka.bigtable.fullname" -}}
{{- printf "%s-%s" .Release.Name "postgresqlbigtable" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "peaka.bigtable.port" -}}
{{- default 5432 .Values.postgresqlbigtable.primary.service.ports.postgresql -}}
{{- end -}}

{{- define "peaka.bigtable.user" -}}
{{- .Values.postgresqlbigtable.auth.username -}}
{{- end -}}

{{- define "peaka.bigtable.database" -}}
{{- .Values.postgresqlbigtable.auth.database -}}
{{- end -}}

{{- define "peaka.bigtable.password" -}}
{{- .Values.postgresqlbigtable.auth.password -}}
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

{{- define "peaka.temporal.frontend.fullname" -}}
{{- printf "%s-temporal-frontend" ( include "peaka.temporal.fullname" . )  -}}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "peaka.temporal.fullname" -}}
{{- if .Values.temporal.fullnameOverride }}
{{- .Values.temporal.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.temporal.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Define the peaka.permify.fullname template with .Release.Name and "permify"
*/}}
{{- define "peaka.permify.fullname" -}}
{{- printf "%s-%s" .Release.Name "permify" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "peaka.dbc.url" -}}
{{- .Values.accessUrl.domain -}}
{{- end }}

{{- define "peaka.dbc.port" -}}
{{- default 4567 .Values.accessUrl.dbcPort -}}
{{- end }}

{{- define "peaka.connectors.defaultOauthClients" }}
  {{- if and .Values.connector.credentials.provider.google.clientId .Values.connector.credentials.provider.google.clientSecret }}
    "google": {
      "clientInfo": {
        "type": "oauth_client_info",
        "clientId": "{{ .Values.connector.credentials.provider.google.clientId }}",
        "clientSecret": "{{ .Values.connector.credentials.provider.google.clientSecret }}"
      }
    },
  {{- end }}
  {{- if and .Values.connector.credentials.provider.google_ads.clientId .Values.connector.credentials.provider.google_ads.clientSecret .Values.connector.credentials.provider.google_ads.developerToken }}
    "google_ads": {
      "clientInfo": {
        "type": "google_ads_oauth_client_info",
        "clientId": "{{ .Values.connector.credentials.provider.google_ads.clientId }}",
        "clientSecret": "{{ .Values.connector.credentials.provider.google_ads.clientSecret }}",
        "developerToken":"{{ .Values.connector.credentials.provider.google_ads.developerToken }}"
      }
    },
  {{- end }}
  {{- if and .Values.connector.credentials.provider.hubspot.clientId .Values.connector.credentials.provider.hubspot.clientSecret }}
    "hubspot": {
      "clientInfo": {
        "type": "oauth_client_info",
        "clientId": "{{ .Values.connector.credentials.provider.hubspot.clientId }}",
        "clientSecret": "{{ .Values.connector.credentials.provider.hubspot.clientSecret }}"
      }
    },
  {{- end }}
  {{- if and .Values.connector.credentials.provider.mailchimp.clientId .Values.connector.credentials.provider.mailchimp.clientSecret }}
    "mailchimp": {
      "clientInfo": {
        "type": "oauth_client_info",
        "clientId": "{{ .Values.connector.credentials.provider.mailchimp.clientId }}",
        "clientSecret": "{{ .Values.connector.credentials.provider.mailchimp.clientSecret }}"
      }
    },
  {{- end }}
  {{- if and .Values.connector.credentials.provider.slack.clientId .Values.connector.credentials.provider.slack.clientSecret }}
    "slack": {
      "clientInfo": {
        "type": "oauth_client_info",
        "clientId": "{{ .Values.connector.credentials.provider.slack.clientId }}",
        "clientSecret": "{{ .Values.connector.credentials.provider.slack.clientSecret }}"
      }
    },
  {{- end }}
  {{- if and .Values.connector.credentials.provider.intercom.clientId .Values.connector.credentials.provider.intercom.clientSecret }}
    "intercom": {
      "clientInfo": {
        "type": "oauth_client_info",
        "clientId": "{{ .Values.connector.credentials.provider.intercom.clientId }}",
        "clientSecret": "{{ .Values.connector.credentials.provider.intercom.clientSecret }}"
      }
    },
   {{- end }}
   {{- if and .Values.connector.credentials.provider.zoho_crm.clientId .Values.connector.credentials.provider.zoho_crm.clientSecret }}
    "zoho_crm": {
      "clientInfo": {
        "type": "oauth_client_info",
        "clientId": "{{ .Values.connector.credentials.provider.zoho_crm.clientId }}",
        "clientSecret": "{{ .Values.connector.credentials.provider.zoho_crm.clientSecret }}"
      }
    },
  {{- end }}
  {{- if and .Values.connector.credentials.provider.linkedin.clientId .Values.connector.credentials.provider.linkedin.clientSecret }}
    "linkedin": {
      "clientInfo": {
        "type": "oauth_client_info",
        "clientId": "{{ .Values.connector.credentials.provider.linkedin.clientId }}",
        "clientSecret": "{{ .Values.connector.credentials.provider.linkedin.clientSecret }}"
      }
    },
  {{- end }}
  {{- if and .Values.connector.credentials.provider.facebook.clientId .Values.connector.credentials.provider.facebook.clientSecret }}
    "facebook": {
      "clientInfo": {
        "type": "oauth_client_info",
        "clientId": "{{ .Values.connector.credentials.provider.facebook.clientId }}",
        "clientSecret":"{{ .Values.connector.credentials.provider.facebook.clientSecret }}"
       }
    },
  {{- end }}
  {{- if and .Values.connector.credentials.provider.pipedrive.clientId .Values.connector.credentials.provider.pipedrive.clientSecret }}
    "pipedrive": {
      "clientInfo": {
          "type": "oauth_client_info",
          "clientId": "{{ .Values.connector.credentials.provider.pipedrive.clientId }}",
          "clientSecret":"{{ .Values.connector.credentials.provider.pipedrive.clientSecret }}"
      }
    },
  {{- end }}
  {{- if and .Values.connector.credentials.provider.dynamics_365.clientId .Values.connector.credentials.provider.dynamics_365.clientSecret .Values.connector.credentials.provider.dynamics_365.tenantId }}
    "dynamics_365": {
      "clientInfo": {
        "type": "microsoft_oauth_client_info",
        "clientId": "{{ .Values.connector.credentials.provider.dynamics_365.clientId }}",
        "clientSecret": "{{ .Values.connector.credentials.provider.dynamics_365.clientSecret }}",
        "tenantId": "{{ .Values.connector.credentials.provider.dynamics_365.tenantId }}"
      }
    },
  {{- end }}
  {{- if and .Values.connector.credentials.provider.microsoft.clientId .Values.connector.credentials.provider.microsoft.clientSecret }}
    "microsoft": {
      "clientInfo": {
        "type": "oauth_client_info",
        "clientId": "{{ .Values.connector.credentials.provider.microsoft.clientId }}",
        "clientSecret": "{{ .Values.connector.credentials.provider.microsoft.clientSecret }}"
      }
    },
  {{- end }}
  {{- if and .Values.connector.credentials.provider.quickbooks_online.clientId .Values.connector.credentials.provider.quickbooks_online.clientSecret }}
    "quickbooks_online": {
      "clientInfo": {
        "type": "oauth_client_info",
        "clientId": "{{ .Values.connector.credentials.provider.quickbooks_online.clientId }}",
        "clientSecret": "{{ .Values.connector.credentials.provider.quickbooks_online.clientSecret }}"
      }
    },
  {{- end }}
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


{{- define "peaka.postgresql.initScripts" -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .name }}
data:
  permify.sql: |
    CREATE DATABASE permify WITH OWNER {{ .username }} ;

  studio.sql: |
    CREATE SCHEMA IF NOT EXISTS studio;
    ALTER SCHEMA studio OWNER TO {{ .username }} ;
    DROP FUNCTION IF EXISTS studio.gen_random_uuid();

    CREATE OR REPLACE FUNCTION studio.gen_random_uuid(
    	)
        RETURNS uuid
        LANGUAGE 'c'
        COST 1
        VOLATILE PARALLEL SAFE
    AS '$libdir/pgcrypto', 'pg_random_uuid'
    ;

    ALTER FUNCTION studio.gen_random_uuid() OWNER TO {{ .username }} ;

  abstract_schema_mapper.sql: |
    SET statement_timeout = 0;
    SET lock_timeout = 0;
    SET idle_in_transaction_session_timeout = 0;
    SET client_encoding = 'UTF8';
    SET standard_conforming_strings = on;
    SELECT pg_catalog.set_config('search_path', '', false);
    SET check_function_bodies = false;
    SET xmloption = content;
    SET client_min_messages = warning;
    SET row_security = off;

    DROP DATABASE {{ .database }} ;
    --
    -- TOC entry 9008 (class 1262 OID 16384)
    -- Name: {{ .database }} ; Type: DATABASE; Schema: -; Owner: {{ .username }}
    --

    CREATE DATABASE {{ .database }}  WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_US.UTF-8';


    ALTER DATABASE {{ .database }}  OWNER TO {{ .username }} ;

    \connect {{ .database }}

    SET statement_timeout = 0;
    SET lock_timeout = 0;
    SET idle_in_transaction_session_timeout = 0;
    SET client_encoding = 'UTF8';
    SET standard_conforming_strings = on;
    SELECT pg_catalog.set_config('search_path', '', false);
    SET check_function_bodies = false;
    SET xmloption = content;
    SET client_min_messages = warning;
    SET row_security = off;

    --
    -- TOC entry 9 (class 2615 OID 16386)
    -- Name: abstract_schema_mapper; Type: SCHEMA; Schema: -; Owner: {{ .username }}
    --

    CREATE SCHEMA abstract_schema_mapper;


    ALTER SCHEMA abstract_schema_mapper OWNER TO {{ .username }} ;

    --
    -- TOC entry 2465 (class 1255 OID 16688)
    -- Name: clone_schema(bigint, text, text, text, text, text, text, boolean, text[], text[]); Type: FUNCTION; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    CREATE FUNCTION abstract_schema_mapper.clone_schema(app_id bigint, app_name text, app_display_name text, source_schema text, dest_schema text, source_external_schema_name text, dest_external_schema_name text, include_recs boolean, tables_to_data_copy text[], replaced_catalog_names text[]) RETURNS void
        LANGUAGE plpgsql
        AS $_$

    DECLARE
        src_oid          oid;
        tbl_oid          oid;
        func_oid         oid;
        con_oid          oid;
        v_func           text;
        v_args           text;
        v_conname        text;
        v_rule           text;
        v_trig           text;
        object           text;
        buffer           text;
        srctbl           text;
        default_         text;
        v_column         text;
        qry              text;
        dest_qry         text;
        v_def            text;
        v_stat           integer;
        sq_last_value    bigint;
        sq_max_value     bigint;
        sq_start_value   bigint;
        sq_increment_by  bigint;
        sq_min_value     bigint;
        sq_cache_value   bigint;
        sq_log_cnt       bigint;
        sq_is_called     boolean;
        sq_is_cycled     boolean;
        sq_cycled        char(10);
        should_copy		 boolean;
        update_queries_str text;
    BEGIN

        -- Check that source_schema exists
        SELECT oid INTO src_oid
        FROM pg_namespace
        WHERE nspname = quote_ident(source_schema);
        IF NOT FOUND
        THEN
            RAISE EXCEPTION 'source schema % does not exist!', source_schema;
        END IF;

        -- Check that dest_schema does not yet exist
        PERFORM nspname
        FROM pg_namespace
        WHERE nspname = quote_ident(dest_schema);
        IF NOT FOUND
        THEN
            EXECUTE 'CREATE SCHEMA ' || quote_ident(dest_schema) ;
        END IF;

        -- Add schema comment
        SELECT description INTO v_def
        FROM pg_description
        WHERE objoid = src_oid
          AND objsubid = 0;
        IF FOUND
        THEN
            EXECUTE 'COMMENT ON SCHEMA ' || quote_ident(dest_schema) || ' IS ' || quote_literal(v_def);
        END IF;

        -- Create sequences
        -- TODO: Find a way to make this sequence's owner is the correct table.
        FOR object IN
            SELECT sequence_name::text
            FROM information_schema.sequences
            WHERE sequence_schema = quote_ident(source_schema)
            LOOP
                EXECUTE 'CREATE SEQUENCE ' || quote_ident(dest_schema) || '.' || quote_ident(object);
                srctbl := quote_ident(source_schema) || '.' || quote_ident(object);

                EXECUTE 'SELECT last_value, max_value, start_value, increment_by, min_value, cache_value, log_cnt, is_cycled, is_called
                  FROM ' || quote_ident(source_schema) || '.' || quote_ident(object) || ';'
                    INTO sq_last_value, sq_max_value, sq_start_value, sq_increment_by, sq_min_value, sq_cache_value, sq_log_cnt, sq_is_cycled, sq_is_called ;

                IF sq_is_cycled
                THEN
                    sq_cycled := 'CYCLE';
                ELSE
                    sq_cycled := 'NO CYCLE';
                END IF;

                EXECUTE 'ALTER SEQUENCE '   || quote_ident(dest_schema) || '.' || quote_ident(object)
                            || ' INCREMENT BY ' || sq_increment_by
                            || ' MINVALUE '     || sq_min_value
                            || ' MAXVALUE '     || sq_max_value
                            || ' START WITH '   || sq_start_value
                            || ' RESTART '      || sq_min_value
                            || ' CACHE '        || sq_cache_value
                            || sq_cycled || ' ;' ;

                buffer := quote_ident(dest_schema) || '.' || quote_ident(object);
                IF include_recs
                THEN
                    EXECUTE 'SELECT setval( ''' || buffer || ''', ' || sq_last_value || ', ' || sq_is_called || ');' ;
                ELSE
                    EXECUTE 'SELECT setval( ''' || buffer || ''', ' || sq_start_value || ', ' || sq_is_called || ');' ;
                END IF;

                -- add sequence comments
                SELECT oid INTO tbl_oid
                FROM pg_class
                WHERE relkind = 'S'
                  AND relnamespace = src_oid
                  AND relname = quote_ident(object);

                SELECT description INTO v_def
                FROM pg_description
                WHERE objoid = tbl_oid
                  AND objsubid = 0;

                IF FOUND
                THEN
                    EXECUTE 'COMMENT ON SEQUENCE ' || quote_ident(dest_schema) || '.' || quote_ident(object)
                                || ' IS ''' || v_def || ''';';
                END IF;

            END LOOP;

    -- Create tables
        FOR object IN
            SELECT TABLE_NAME::text
            FROM information_schema.tables
            WHERE table_schema = quote_ident(source_schema)
              AND table_type = 'BASE TABLE'

            LOOP
                buffer := quote_ident(dest_schema) || '.' || quote_ident(object);
                EXECUTE 'CREATE TABLE IF NOT EXISTS ' || buffer || ' (LIKE ' || quote_ident(source_schema) || '.' || quote_ident(object)
                    || ' INCLUDING ALL)';

                -- Add table comment
                SELECT oid INTO tbl_oid
                FROM pg_class
                WHERE relkind = 'r'
                  AND relnamespace = src_oid
                  AND relname = quote_ident(object);

                SELECT description INTO v_def
                FROM pg_description
                WHERE objoid = tbl_oid
                  AND objsubid = 0;

                IF FOUND
                THEN
                    EXECUTE 'COMMENT ON TABLE ' || quote_ident(dest_schema) || '.' || quote_ident(object)
                                || ' IS ''' || v_def || ''';';
                END IF;

                -- We hope PostgreSQL uses short circuit
                should_copy :=
                            (object != 'sm_cache') AND (
                            (include_recs) OR
                            ((SELECT * FROM UNNEST(tables_to_data_copy) AS tables_to_data WHERE (tables_to_data = object)) IS NOT NULL));
                IF (should_copy)
                THEN
                    -- Insert records from source table
                    EXECUTE 'INSERT INTO ' || buffer || ' SELECT * FROM ' || quote_ident(source_schema) || '.' || quote_ident(object) || ' ON CONFLICT DO NOTHING;';
                END IF;

                FOR v_column, default_ IN
                    SELECT column_name::text,
                           REPLACE(column_default::text, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.' )
                    FROM information_schema.COLUMNS
                    WHERE table_schema = dest_schema
                      AND TABLE_NAME = object
                      AND column_default LIKE 'nextval(%' || quote_ident(source_schema) || '%::regclass)'
                    LOOP
                        EXECUTE 'ALTER TABLE ' || buffer || ' ALTER COLUMN ' || v_column || ' SET DEFAULT ' || default_;

                    END LOOP;

            END LOOP;

        -- set column statistics
        FOR tbl_oid, srctbl IN
            SELECT oid, relname
            FROM pg_class
            WHERE relnamespace = src_oid
              AND relkind = 'r'

            LOOP

                FOR v_column, v_stat IN
                    SELECT attname, attstattarget
                    FROM pg_attribute
                    WHERE attrelid = tbl_oid
                      AND attnum > 0 AND attisdropped IS FALSE

                    LOOP

                        buffer := quote_ident(dest_schema) || '.' || quote_ident(srctbl);
    --      RAISE EXCEPTION 'ALTER TABLE % ALTER COLUMN % SET STATISTICS %', buffer, v_column, v_stat::text;
                        EXECUTE 'ALTER TABLE ' || buffer || ' ALTER COLUMN ' || quote_ident(v_column) || ' SET STATISTICS ' || v_stat || ';';

                    END LOOP;
            END LOOP;

    --  add FK constraint
        FOR qry IN
            SELECT 'ALTER TABLE ' || quote_ident(dest_schema) || '.' || quote_ident(rn.relname)
                       || ' ADD CONSTRAINT ' || quote_ident(ct.conname) || ' ' || pg_get_constraintdef(ct.oid) || ';'
            FROM pg_constraint ct
                     JOIN pg_class rn ON rn.oid = ct.conrelid
            WHERE connamespace = src_oid
              AND rn.relkind = 'r'
              AND ct.contype = 'f'

            LOOP
            BEGIN -- for exception
                EXECUTE qry;
                EXCEPTION
                    WHEN OTHERS THEN NULL;
            END; -- for exception

            END LOOP;

        -- Add constraint comment
        FOR con_oid IN
            SELECT oid
            FROM pg_constraint
            WHERE conrelid = tbl_oid

            LOOP
                SELECT conname INTO v_conname
                FROM pg_constraint
                WHERE oid = con_oid;

                SELECT description INTO v_def
                FROM pg_description
                WHERE objoid = con_oid;

                IF FOUND
                THEN
                    EXECUTE 'COMMENT ON CONSTRAINT ' || v_conname || ' ON ' || quote_ident(dest_schema) || '.' || quote_ident(object)
                                || ' IS ''' || v_def || ''';';
                END IF;

            END LOOP;

    -- Create views
        FOR object IN
            SELECT table_name::text,
                   view_definition
            FROM information_schema.views
            WHERE table_schema = quote_ident(source_schema)

            LOOP
                buffer := quote_ident(dest_schema) || '.' || quote_ident(object);
                SELECT view_definition INTO v_def
                FROM information_schema.views
                WHERE table_schema = quote_ident(source_schema)
                  AND table_name = quote_ident(object);

                EXECUTE 'CREATE OR REPLACE VIEW ' || buffer || ' AS ' || v_def || ';' ;

                -- Add comment
                SELECT oid INTO tbl_oid
                FROM pg_class
                WHERE relkind = 'v'
                  AND relnamespace = src_oid
                  AND relname = quote_ident(object);

                SELECT description INTO v_def
                FROM pg_description
                WHERE objoid = tbl_oid
                  AND objsubid = 0;

                IF FOUND
                THEN
                    EXECUTE 'COMMENT ON VIEW ' || quote_ident(dest_schema) || '.' || quote_ident(object)
                                || ' IS ' || quote_literal(v_def);
                END IF;

            END LOOP;

    -- Create functions
        FOR func_oid IN
            SELECT oid, proargnames
            FROM pg_proc
            WHERE pronamespace = src_oid

            LOOP
                SELECT pg_get_functiondef(func_oid) INTO qry;
                SELECT proname, oidvectortypes(proargtypes) INTO v_func, v_args
                FROM pg_proc
                WHERE oid = func_oid;
                SELECT replace(qry, quote_ident(source_schema) || '.', quote_ident(dest_schema) || '.') INTO dest_qry;
                EXECUTE dest_qry;

                -- Add function comment
                SELECT description INTO v_def
                FROM pg_description
                WHERE objoid = func_oid
                  AND objsubid = 0;

                IF FOUND
                THEN
    --        RAISE NOTICE 'func_oid %, object %,  v_args %',  func_oid::text, quote_ident(object), v_args;
                    EXECUTE 'COMMENT ON FUNCTION ' || quote_ident(dest_schema) || '.' || quote_ident(v_func) || '(' || v_args || ')'
                                || ' IS ' || quote_literal(v_def) ||';' ;
                END IF;

            END LOOP;

        -- add Rules
        FOR v_def IN
            SELECT definition
            FROM pg_rules
            WHERE schemaname = quote_ident(source_schema)

            LOOP

                IF v_def IS NOT NULL
                THEN
                    SELECT replace(v_def, 'TO ', 'TO ' || quote_ident(dest_schema) || '.') INTO v_def;
                    EXECUTE ' ' || v_def;
                END IF;
            END LOOP;

        -- add triggers
        FOR v_def IN
            SELECT pg_get_triggerdef(oid)
            FROM pg_trigger
            WHERE tgname NOT LIKE 'RI_%'
              AND tgrelid IN (SELECT oid
                              FROM pg_class
                              WHERE relkind = 'r'
                                AND relnamespace = src_oid)

            LOOP
            BEGIN -- for exception
            --SELECT replace(v_def, ' ON ' || quote_ident(source_schema), ' ON ' || quote_ident(dest_schema)) INTO dest_qry;
            --SELECT replace(dest_qry, ' FOR EACH ROW EXECUTE FUNCTION ' || quote_ident(source_schema), ' FOR EACH ROW EXECUTE FUNCTION ' || quote_ident(dest_schema)) INTO dest_qry;
                SELECT replace(v_def, ' ' || quote_ident(source_schema), ' ' || quote_ident(dest_schema)) INTO dest_qry;
                raise notice 'Trigger query: %', dest_qry;
                EXECUTE dest_qry;
                EXCEPTION
                    WHEN OTHERS THEN NULL;
            END; -- for exception
            END LOOP;
        --  Disable inactive triggers
        --  D = disabled
        FOR tbl_oid IN
            SELECT oid
            FROM pg_trigger
            WHERE tgenabled = 'D'
              AND tgname NOT LIKE 'RI_%'
              AND tgrelid IN (SELECT oid
                              FROM pg_class
                              WHERE relkind = 'r'
                                AND relnamespace = src_oid)
            LOOP
                SELECT t.tgname, c.relname INTO object, srctbl
                FROM pg_trigger t
                         JOIN pg_class c ON c.oid = t.tgrelid
                WHERE t.oid = tbl_oid;

                IF FOUND
                THEN
                    EXECUTE 'ALTER TABLE ' || dest_schema || '.' || srctbl || ' DISABLE TRIGGER ' || object || ';';
                END IF;

            END LOOP;

        -- Add index comment

        FOR tbl_oid IN
            SELECT oid
            FROM pg_class
            WHERE relkind = 'i'
              AND relnamespace = src_oid

            LOOP

                SELECT relname INTO object
                FROM pg_class
                WHERE oid = tbl_oid;
                SELECT description INTO v_def
                FROM pg_description
                WHERE objoid = tbl_oid
                  AND objsubid = 0;

                IF FOUND
                THEN
                    EXECUTE 'COMMENT ON INDEX ' || quote_ident(dest_schema) || '.' || quote_ident(object)
                                || ' IS ''' || v_def || ''';';
                END IF;

            END LOOP;

        -- add rule comments
        FOR con_oid IN
            SELECT oid, *
            FROM pg_rewrite
            WHERE rulename <> '_RETURN'::name

            LOOP

                SELECT rulename, ev_class INTO v_rule, tbl_oid
                FROM pg_rewrite
                WHERE oid = con_oid;

                SELECT relname INTO object
                FROM pg_class
                WHERE oid = tbl_oid
                  AND relkind = 'r';

                SELECT description INTO v_def
                FROM pg_description
                WHERE objoid = con_oid
                  AND objsubid = 0;

                IF FOUND
                THEN
                    EXECUTE 'COMMENT ON RULE ' || v_rule || ' ON ' || quote_ident(dest_schema) || '.' || object || ' IS ' || quote_literal(v_def);
                END IF;

            END LOOP;

        -- add trigger comments
        FOR con_oid IN
            SELECT oid, *
            FROM pg_trigger
            WHERE tgname NOT LIKE 'RI_%'

            LOOP

                SELECT tgname, tgrelid INTO v_trig, tbl_oid
                FROM pg_trigger
                WHERE oid = con_oid;

                SELECT relname INTO object
                FROM pg_class
                WHERE oid = tbl_oid
                  AND relkind = 'r';

                SELECT description INTO v_def
                FROM pg_description
                WHERE objoid = con_oid
                  AND objsubid = 0;

                IF FOUND
                THEN
                    EXECUTE 'COMMENT ON TRIGGER ' || v_trig || ' ON ' || quote_ident(dest_schema) || '.' || object || ' IS ' || quote_literal(v_def);
                END IF;

            END LOOP;

        -- INSERT APP into the system if needed
        IF app_name IS NOT NULL
        THEN
            INSERT INTO abstract_schema_mapper.sm_app (_id, _name, _display_name, _deleted) VALUES (app_id, app_name, app_display_name, 'false');
        END IF;

        -- Update Internal Catalog Schema Name
        -- EXECUTE 'UPDATE "' || dest_schema || '".sm_schema SET _name = ''' || dest_schema || ''' WHERE "_name" = ''' || source_schema || '''';

        -- Update external catalogs and queries
        IF replaced_catalog_names IS NOT NULL
        THEN
            FOR i_index IN 1 .. ARRAY_UPPER(replaced_catalog_names, 1) BY 3
                LOOP
                    -- Update external catalogs
                    EXECUTE 'UPDATE "' || dest_schema || '".sm_catalog
                        SET _name = $2, _props = $3 ::jsonb
                        WHERE _name = $1' USING replaced_catalog_names[i_index], replaced_catalog_names[i_index + 1], replaced_catalog_names[i_index + 2];

                    -- Update queries
                    update_queries_str = format(
                        'UPDATE %I.sm_query '
                        'SET _compiled_query = processed._compiled_query '
                        'FROM (SELECT _id, REPLACE(_compiled_query, %L, %L) AS _compiled_query FROM %I.sm_query) AS processed '
                        'WHERE %I.sm_query._id = processed._id',
                         dest_schema, replaced_catalog_names[i_index], replaced_catalog_names[i_index + 1], dest_schema, dest_schema);
                    EXECUTE update_queries_str;

                END LOOP;
        END IF;

        RETURN;
    END;

    $_$;


    ALTER FUNCTION abstract_schema_mapper.clone_schema(app_id bigint, app_name text, app_display_name text, source_schema text, dest_schema text, source_external_schema_name text, dest_external_schema_name text, include_recs boolean, tables_to_data_copy text[], replaced_catalog_names text[]) OWNER TO {{ .username }} ;

    --
    -- TOC entry 2270 (class 1255 OID 16691)
    -- Name: create_column(text, text, text[], jsonb, integer); Type: FUNCTION; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    CREATE FUNCTION abstract_schema_mapper.create_column(schema_name text, table_name text, execute_statements text[], column_props jsonb, order_input integer) RETURNS jsonb
        LANGUAGE plpgsql
        AS $$
    DECLARE
        execute_statement text;
        column_props_with_order jsonb;
        order_number integer;
        count_sql text;
    BEGIN
        -- CREATE COLUMN and CONSTRAINTS if any
        EXECUTE format('SELECT abstract_schema_mapper.execute_statements_sequentially(%L)', execute_statements);

        -- UPDATE order number props
        IF (order_input = -1) THEN
            count_sql = format('SELECT COUNT(*) FROM %I.sm_column WHERE _table_name = %L', schema_name, table_name);
            RAISE NOTICE 'Count sql: [%]', count_sql;
            EXECUTE count_sql INTO order_number;
        ELSE
            order_number := order_input;
        END IF;
        column_props_with_order = column_props || jsonb_build_object('order', order_number);

        -- UPDATE _id and insert
        RETURN abstract_schema_mapper.create_column_props_with_id_corrected(
            schema_name,
            table_name,
            column_props_with_order);
    END
    $$;


    ALTER FUNCTION abstract_schema_mapper.create_column(schema_name text, table_name text, execute_statements text[], column_props jsonb, order_input integer) OWNER TO {{ .username }} ;

    --
    -- TOC entry 2271 (class 1255 OID 16692)
    -- Name: create_column_props_with_id_corrected(text, text, jsonb); Type: FUNCTION; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    CREATE FUNCTION abstract_schema_mapper.create_column_props_with_id_corrected(schema_name text, table_name text, params jsonb) RETURNS jsonb
        LANGUAGE plpgsql
        AS $$
    DECLARE
        val_id bigint;
        params_with_id jsonb;
        insert_params_query text;
    BEGIN
            val_id = abstract_schema_mapper.next_id();
            --params_with_id = params || jsonb_build_object('id', val_id) - '_id';
            params_with_id = params || jsonb_build_object('id', val_id);
            --RAISE NOTICE 'New params: [%]', params_with_id;
            insert_params_query = format(
                'INSERT INTO %I.sm_column (_id, _name, _display_name, _table_name, _data_type, _props) '
                'VALUES(%L, %L, %L, %L, %L, %L ::json)',
                schema_name, val_id, params->>'name', params->>'displayName', table_name, params->>'dataType', params_with_id);
            --RAISE NOTICE 'Insert col: [%]', insert_params_query;
            EXECUTE insert_params_query;
            RETURN params_with_id;
    END
    $$;


    ALTER FUNCTION abstract_schema_mapper.create_column_props_with_id_corrected(schema_name text, table_name text, params jsonb) OWNER TO {{ .username }} ;

    --
    -- TOC entry 2272 (class 1255 OID 16693)
    -- Name: create_table(text, text, jsonb, jsonb, jsonb, jsonb, jsonb, jsonb, jsonb, jsonb); Type: FUNCTION; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    CREATE FUNCTION abstract_schema_mapper.create_table(schema_name text, table_name text, id_params jsonb, version_params jsonb, created_time_params jsonb, created_by_params jsonb, last_modified_time_params jsonb, last_modified_by_params jsonb, session_params jsonb, first_col_params jsonb) RETURNS boolean
        LANGUAGE plpgsql
        AS $_$

    DECLARE
        create_table_query text;
        -- table_comment text;
        crate_trigger_function text;
        create_trigger text;
        create_view_query text;

        insert_cols_query text;
        insert_params_query text;
        val_id bigint;
        params_with_id jsonb;

        view_name text;

    BEGIN
        -- check table exists
        IF EXISTS (
              SELECT FROM pg_catalog.pg_class c
              JOIN   pg_catalog.pg_namespace n ON n.oid = c.relnamespace
              WHERE  n.nspname = schema_name
              AND    c.relname = table_name
              ) THEN

            RETURN FALSE;
            RAISE EXCEPTION 'Table already created before: %I', table_name;

        ELSE
            -- create the table and simple text field
            create_table_query = format(
                'CREATE TABLE IF NOT EXISTS %I.%I ('
                '   PRIMARY KEY (_id),'
                '   text VARCHAR(100000)'
                ') '
                'INHERITS (abstract_schema_mapper.abstract_row)', schema_name, table_name);
            --RAISE NOTICE 'Creating query: [%]', create_table_query;
            EXECUTE create_table_query;

            -- create table trigger function
            /*
            crate_trigger_function = format(
                'CREATE OR REPLACE FUNCTION %I."%s_insert_update_trigger"() RETURNS trigger '
                'LANGUAGE ''plpgsql'' COST 100 VOLATILE NOT LEAKPROOF '
                'AS $$'
                '	BEGIN'
                '		NEW._version = COALESCE(OLD._version, 0) + 1;'
                '		NEW._last_modified_time = CURRENT_TIMESTAMP;'
                '		RETURN NEW;'
                '	END;'
                ' $$',
                schema_name, table_name);
            --RAISE NOTICE 'Creating trigger function: [%]', crate_trigger_function;
            EXECUTE crate_trigger_function;
            */
            -- create table trigger
            create_trigger = format(
                'CREATE TRIGGER "%s_insert_update_trigger" '
                'BEFORE INSERT OR UPDATE '
                '	ON %I.%I '
                'FOR EACH ROW '
                'EXECUTE FUNCTION "abstract_schema_mapper"."insert_update_trigger"();',
            table_name, schema_name, table_name);
            --RAISE NOTICE 'Table trigger: [%]', create_trigger;
            EXECUTE create_trigger;

            -- insert params to sm_column
            -- id col
            insert_cols_query = format(
                'SELECT abstract_schema_mapper.create_column_props_with_id_corrected('
                '%L, %L, %L)',
                schema_name, table_name, id_params);
            --RAISE NOTICE 'Insert sel col: [%]', insert_cols_query;
            EXECUTE insert_cols_query;

            -- version col
            insert_cols_query = format(
                'SELECT abstract_schema_mapper.create_column_props_with_id_corrected('
                '%L, %L, %L)',
                schema_name, table_name, version_params);
            --RAISE NOTICE 'Insert sel col: [%]', insert_cols_query;
            EXECUTE insert_cols_query;

            -- created_time col
            insert_cols_query = format(
                'SELECT abstract_schema_mapper.create_column_props_with_id_corrected('
                '%L, %L, %L)',
                schema_name, table_name, created_time_params);
            --RAISE NOTICE 'Insert sel col: [%]', insert_cols_query;
            EXECUTE insert_cols_query;

            -- _created_by col
            insert_cols_query = format(
                'SELECT abstract_schema_mapper.create_column_props_with_id_corrected('
                '%L, %L, %L)',
                schema_name, table_name, created_by_params);
            --RAISE NOTICE 'Insert sel col: [%]', insert_cols_query;
            EXECUTE insert_cols_query;

            -- _last_modified_time col
            insert_cols_query = format(
                'SELECT abstract_schema_mapper.create_column_props_with_id_corrected('
                '%L, %L, %L)',
                schema_name, table_name, last_modified_time_params);
            --RAISE NOTICE 'Insert sel col: [%]', insert_cols_query;
            EXECUTE insert_cols_query;

            -- _last_modified_by col
            insert_cols_query = format(
                'SELECT abstract_schema_mapper.create_column_props_with_id_corrected('
                '%L, %L, %L)',
                schema_name, table_name, last_modified_by_params);
            --RAISE NOTICE 'Insert sel col: [%]', insert_cols_query;
            EXECUTE insert_cols_query;

            -- _session col
            insert_cols_query = format(
                'SELECT abstract_schema_mapper.create_column_props_with_id_corrected('
                '%L, %L, %L)',
                schema_name, table_name, session_params);
            --RAISE NOTICE 'Insert sel col: [%]', insert_cols_query;
            EXECUTE insert_cols_query;

            -- text col
            insert_cols_query = format(
                'SELECT abstract_schema_mapper.create_column_props_with_id_corrected('
                '%L, %L, %L)',
                schema_name, table_name, first_col_params);

            EXECUTE insert_cols_query;

            -- create the table query as comment
            --table_comment = format('COMMENT ON TABLE %I.%I IS ''SELECT * FROM %I.%I ORDER BY _id''',
            --    schema_name, table_name,
            --    schema_name, table_name);
            --EXECUTE table_comment;
            --RAISE NOTICE 'Table comment: [%]', table_comment;

            -- create view
            --view_name = format('sm_view_%s', table_name);
            --create_view_query = format('CREATE VIEW %I.%I AS SELECT * FROM %I.%I',
            --    schema_name, view_name,
            --    schema_name, table_name);
            --EXECUTE create_view_query;
            --RAISE NOTICE 'View query: [%]', create_view_query;

            RETURN TRUE;
        END IF;
    END;

    $_$;


    ALTER FUNCTION abstract_schema_mapper.create_table(schema_name text, table_name text, id_params jsonb, version_params jsonb, created_time_params jsonb, created_by_params jsonb, last_modified_time_params jsonb, last_modified_by_params jsonb, session_params jsonb, first_col_params jsonb) OWNER TO {{ .username }} ;

    --
    -- TOC entry 2273 (class 1255 OID 16694)
    -- Name: delete_column(text, text, text); Type: FUNCTION; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    CREATE FUNCTION abstract_schema_mapper.delete_column(schema_name text, table_name text, column_name text) RETURNS void
        LANGUAGE plpgsql
        AS $$
    DECLARE
        drop_statement text;
        update_statement text;
        select_statement text;
        col_id bigint;
        props jsonb;
        col_order integer;
        delete_statement text;
    BEGIN
        -- DROP COLUMN
        drop_statement = format('ALTER TABLE %I.%I DROP COLUMN %I CASCADE', schema_name, table_name, column_name);
        RAISE NOTICE 'Drop col: [%]', drop_statement;
        EXECUTE drop_statement;

        -- UPDATE order number props
        select_statement = format(
            'SELECT _id, _props, _props->>''order'' AS integer FROM %I.sm_column WHERE _table_name = %L AND _name = %L',
            schema_name, table_name, column_name);
        RAISE NOTICE 'Select col: [%]', select_statement;
        EXECUTE select_statement INTO col_id, props, col_order;

        update_statement = format(
            'UPDATE %I.sm_column '
            'SET _props = jsonb_set(_props, ''{order}'', REPLACE(_props->>''order'', _props->>''order'', CAST(CAST(_props->>''order'' AS INTEGER)-1 AS TEXT)) ::jsonb, false) '
            'WHERE (CAST(_props->>''order'' AS INTEGER) >= %L)'
        ,schema_name, col_order);
        RAISE NOTICE 'Update props: [%]', update_statement;
        EXECUTE update_statement;

        -- DELETE FROM sm_column
        delete_statement = format('DELETE FROM %I.sm_column WHERE _id = %L', schema_name, col_id);
        RAISE NOTICE 'Delete column statement: [%]', delete_statement;
        EXECUTE delete_statement;
    END
    $$;


    ALTER FUNCTION abstract_schema_mapper.delete_column(schema_name text, table_name text, column_name text) OWNER TO {{ .username }} ;

    --
    -- TOC entry 2274 (class 1255 OID 16695)
    -- Name: delete_table(text, text); Type: FUNCTION; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    CREATE FUNCTION abstract_schema_mapper.delete_table(schema_name text, table_name text) RETURNS void
        LANGUAGE plpgsql
        AS $$
    DECLARE
        drop_table_query text;
        drop_columns_query text;
    BEGIN
        -- DROP TABLE IF EXISTS
        drop_table_query = format('DROP TABLE IF EXISTS %I.%I CASCADE', schema_name, table_name);
        RAISE NOTICE 'Drop table: [%]', drop_table_query;
        EXECUTE drop_table_query;

        -- DROP TABLE FROM sm_columns
        drop_columns_query = format('DELETE FROM %I.sm_column WHERE _table_name = %L', schema_name, table_name);
        RAISE NOTICE 'Delete cols query: [%]', drop_columns_query;
        EXECUTE drop_columns_query;
    END
    $$;


    ALTER FUNCTION abstract_schema_mapper.delete_table(schema_name text, table_name text) OWNER TO {{ .username }} ;

    --
    -- TOC entry 2275 (class 1255 OID 16696)
    -- Name: execute_statements_sequentially(text[]); Type: FUNCTION; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    CREATE FUNCTION abstract_schema_mapper.execute_statements_sequentially(execute_statements text[]) RETURNS void
        LANGUAGE plpgsql
        AS $$
    DECLARE
        execute_statement text;
    BEGIN
        -- execute the statement
        FOREACH execute_statement IN ARRAY execute_statements
        LOOP
            RAISE NOTICE 'Execution statement: [%]', execute_statement;
            EXECUTE execute_statement;
        END LOOP;
    END
    $$;


    ALTER FUNCTION abstract_schema_mapper.execute_statements_sequentially(execute_statements text[]) OWNER TO {{ .username }} ;

    --
    -- TOC entry 2276 (class 1255 OID 16697)
    -- Name: insert_update_trigger(); Type: FUNCTION; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    CREATE FUNCTION abstract_schema_mapper.insert_update_trigger() RETURNS trigger
        LANGUAGE plpgsql
        AS $$
       BEGIN
           NEW._version = COALESCE(OLD._version, 0) + 1;
           NEW._last_modified_time = CURRENT_TIMESTAMP;
           RETURN NEW;
       END;
    $$;


    ALTER FUNCTION abstract_schema_mapper.insert_update_trigger() OWNER TO {{ .username }} ;

    --
    -- TOC entry 2277 (class 1255 OID 16698)
    -- Name: next_id(); Type: FUNCTION; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    CREATE FUNCTION abstract_schema_mapper.next_id(OUT result bigint) RETURNS bigint
        LANGUAGE plpgsql
        AS $$
    DECLARE
        our_epoch bigint := 1640995200000; -- 01 Jan 2022 00:00:00 GMT
        seq_id bigint;
        now_millis bigint;
        shard_id int := 0;
    BEGIN
        SELECT MOD(nextval('abstract_schema_mapper.table_id_seq'), 1024) INTO seq_id;
        SELECT FLOOR(EXTRACT(EPOCH FROM clock_timestamp()) * 1000) INTO now_millis;
        result := (now_millis - our_epoch) << 23;
        result := result | (shard_id <<10);
        result := result | (seq_id);
    END;

    $$;


    ALTER FUNCTION abstract_schema_mapper.next_id(OUT result bigint) OWNER TO {{ .username }} ;

    --
    -- TOC entry 2278 (class 1255 OID 16699)
    -- Name: replace_recursive(text, text[]); Type: FUNCTION; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    CREATE FUNCTION abstract_schema_mapper.replace_recursive(search text, from_to text[]) RETURNS text
        LANGUAGE plpgsql
        AS $$
    BEGIN
        IF (array_length(from_to,1) > 2) THEN
            RETURN abstract_schema_mapper.replace_recursive(
                    replace(search, from_to[1], from_to[2]),
                    from_to[3:array_upper(from_to,1)]);
        ELSE
            RETURN replace(search, from_to[1], from_to[2]);
        END IF;
    END;$$;


    ALTER FUNCTION abstract_schema_mapper.replace_recursive(search text, from_to text[]) OWNER TO {{ .username }} ;

    --
    -- TOC entry 2279 (class 1255 OID 16700)
    -- Name: update_table_name(text, text, text); Type: FUNCTION; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    CREATE FUNCTION abstract_schema_mapper.update_table_name(schema_name text, table_old_name text, table_new_name text) RETURNS void
        LANGUAGE plpgsql
        AS $$
    DECLARE
        rename_table_query text;
        rename_columns_query text;
    BEGIN
        -- ALTER TABLE NAME
        rename_table_query = format(
            'ALTER TABLE %I.%I RENAME TO %I',
            schema_name, table_old_name, table_new_name);
        RAISE NOTICE 'Rename table: [%]', rename_table_query;
        EXECUTE rename_table_query;

        -- UPDATE sm_columns
        rename_columns_query = format(
            'UPDATE %I.sm_column SET _table_name = %L WHERE _table_name = %L',
            schema_name, table_new_name, table_old_name);
        RAISE NOTICE 'Column table rename: [%]', rename_columns_query;
        EXECUTE rename_columns_query;
    END
    $$;


    ALTER FUNCTION abstract_schema_mapper.update_table_name(schema_name text, table_old_name text, table_new_name text) OWNER TO {{ .username }} ;

    SET default_tablespace = '';

    SET default_table_access_method = heap;

    --
    -- TOC entry 579 (class 1259 OID 16884)
    -- Name: abstract_identity; Type: TABLE; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    CREATE TABLE abstract_schema_mapper.abstract_identity (
        _id bigint DEFAULT abstract_schema_mapper.next_id() NOT NULL,
        _name text NOT NULL,
        _display_name text NOT NULL,
        _version bigint DEFAULT '1'::bigint NOT NULL,
        _created_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
        _created_by bigint DEFAULT '1'::bigint NOT NULL,
        _last_modified_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
        _last_modified_by bigint DEFAULT '1'::bigint NOT NULL
    );


    ALTER TABLE abstract_schema_mapper.abstract_identity OWNER TO {{ .username }} ;

    --
    -- TOC entry 580 (class 1259 OID 16895)
    -- Name: abstract_row; Type: TABLE; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    CREATE TABLE abstract_schema_mapper.abstract_row (
        _id bigint DEFAULT abstract_schema_mapper.next_id() NOT NULL,
        _version bigint DEFAULT '1'::bigint NOT NULL,
        _created_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
        _created_by bigint DEFAULT '1'::bigint NOT NULL,
        _last_modified_time timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
        _last_modified_by bigint DEFAULT '1'::bigint NOT NULL,
        _session bigint DEFAULT 1 NOT NULL
    );


    ALTER TABLE abstract_schema_mapper.abstract_row OWNER TO {{ .username }} ;

    --
    -- TOC entry 581 (class 1259 OID 16905)
    -- Name: sm_app; Type: TABLE; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    CREATE TABLE abstract_schema_mapper.sm_app (
        _deleted boolean DEFAULT false NOT NULL
    )
    INHERITS (abstract_schema_mapper.abstract_identity);


    ALTER TABLE abstract_schema_mapper.sm_app OWNER TO {{ .username }} ;


    -- Table: abstract_schema_mapper.sm_query_share

    -- DROP TABLE IF EXISTS abstract_schema_mapper.sm_query_share;

    CREATE TABLE IF NOT EXISTS abstract_schema_mapper.sm_query_share
    (
        _cats text[] NOT NULL,
        _cat_instances int[] NOT NULL,
        _query_text text NOT NULL,
        CONSTRAINT sm_query_share_pkey PRIMARY KEY (_id)
    )
        INHERITS (abstract_schema_mapper.abstract_identity)

    TABLESPACE pg_default;

    ALTER TABLE IF EXISTS abstract_schema_mapper.sm_query_share
        OWNER to {{ .username }} ;

    -- Trigger: sm_query_share_insert_update_trigger

    -- DROP TRIGGER IF EXISTS sm_query_share_insert_update_trigger ON abstract_schema_mapper.sm_query_share;

    CREATE OR REPLACE TRIGGER sm_query_share_insert_update_trigger
        BEFORE INSERT OR UPDATE
        ON abstract_schema_mapper.sm_query_share
        FOR EACH ROW
        EXECUTE FUNCTION abstract_schema_mapper.insert_update_trigger();
    --
    -- TOC entry 582 (class 1259 OID 16917)
    -- Name: sm_cat_share; Type: TABLE; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    CREATE TABLE abstract_schema_mapper.sm_cat_share (
        _src_app_id bigint NOT NULL,
        _dst_app_id bigint NOT NULL,
        _src_cat_id bigint NOT NULL,
        _dst_cat_id bigint NOT NULL
    )
    INHERITS (abstract_schema_mapper.abstract_row);


    ALTER TABLE abstract_schema_mapper.sm_cat_share OWNER TO {{ .username }} ;

    --
    -- TOC entry 583 (class 1259 OID 16927)
    -- Name: table_id_seq; Type: SEQUENCE; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    CREATE SEQUENCE abstract_schema_mapper.table_id_seq
        START WITH 0
        INCREMENT BY 1
        MINVALUE 0
        NO MAXVALUE
        CACHE 100;


    ALTER TABLE abstract_schema_mapper.table_id_seq OWNER TO {{ .username }} ;

    --
    -- TOC entry 8828 (class 2604 OID 29615)
    -- Name: sm_app _id; Type: DEFAULT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.sm_app ALTER COLUMN _id SET DEFAULT abstract_schema_mapper.next_id();


    --
    -- TOC entry 8829 (class 2604 OID 29616)
    -- Name: sm_app _version; Type: DEFAULT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.sm_app ALTER COLUMN _version SET DEFAULT '1'::bigint;


    --
    -- TOC entry 8830 (class 2604 OID 29617)
    -- Name: sm_app _created_time; Type: DEFAULT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.sm_app ALTER COLUMN _created_time SET DEFAULT CURRENT_TIMESTAMP;


    --
    -- TOC entry 8831 (class 2604 OID 29618)
    -- Name: sm_app _created_by; Type: DEFAULT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.sm_app ALTER COLUMN _created_by SET DEFAULT '1'::bigint;


    --
    -- TOC entry 8832 (class 2604 OID 29619)
    -- Name: sm_app _last_modified_time; Type: DEFAULT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.sm_app ALTER COLUMN _last_modified_time SET DEFAULT CURRENT_TIMESTAMP;


    --
    -- TOC entry 8833 (class 2604 OID 29620)
    -- Name: sm_app _last_modified_by; Type: DEFAULT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.sm_app ALTER COLUMN _last_modified_by SET DEFAULT '1'::bigint;


    --
    -- TOC entry 8835 (class 2604 OID 29621)
    -- Name: sm_cat_share _id; Type: DEFAULT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.sm_cat_share ALTER COLUMN _id SET DEFAULT abstract_schema_mapper.next_id();


    --
    -- TOC entry 8836 (class 2604 OID 29622)
    -- Name: sm_cat_share _version; Type: DEFAULT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.sm_cat_share ALTER COLUMN _version SET DEFAULT '1'::bigint;


    --
    -- TOC entry 8837 (class 2604 OID 29623)
    -- Name: sm_cat_share _created_time; Type: DEFAULT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.sm_cat_share ALTER COLUMN _created_time SET DEFAULT CURRENT_TIMESTAMP;


    --
    -- TOC entry 8838 (class 2604 OID 29624)
    -- Name: sm_cat_share _created_by; Type: DEFAULT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.sm_cat_share ALTER COLUMN _created_by SET DEFAULT '1'::bigint;


    --
    -- TOC entry 8839 (class 2604 OID 29625)
    -- Name: sm_cat_share _last_modified_time; Type: DEFAULT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.sm_cat_share ALTER COLUMN _last_modified_time SET DEFAULT CURRENT_TIMESTAMP;


    --
    -- TOC entry 8840 (class 2604 OID 29626)
    -- Name: sm_cat_share _last_modified_by; Type: DEFAULT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.sm_cat_share ALTER COLUMN _last_modified_by SET DEFAULT '1'::bigint;


    --
    -- TOC entry 8841 (class 2604 OID 29627)
    -- Name: sm_cat_share _session; Type: DEFAULT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.sm_cat_share ALTER COLUMN _session SET DEFAULT 1;


    --
    -- TOC entry 8998 (class 0 OID 16884)
    -- Dependencies: 579
    -- Data for Name: abstract_identity; Type: TABLE DATA; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --



    --
    -- TOC entry 8999 (class 0 OID 16895)
    -- Dependencies: 580
    -- Data for Name: abstract_row; Type: TABLE DATA; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --



    --
    -- TOC entry 9000 (class 0 OID 16905)
    -- Dependencies: 581
    -- Data for Name: sm_app; Type: TABLE DATA; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    --
    -- TOC entry 9009 (class 0 OID 0)
    -- Dependencies: 583
    -- Name: table_id_seq; Type: SEQUENCE SET; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    SELECT pg_catalog.setval('abstract_schema_mapper.table_id_seq', 15317583, true);


    --
    -- TOC entry 8843 (class 2606 OID 39170)
    -- Name: abstract_identity abstract_identity_pkey; Type: CONSTRAINT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.abstract_identity
        ADD CONSTRAINT abstract_identity_pkey PRIMARY KEY (_id);


    --
    -- TOC entry 8845 (class 2606 OID 39172)
    -- Name: abstract_row abstract_row_pkey; Type: CONSTRAINT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.abstract_row
        ADD CONSTRAINT abstract_row_pkey PRIMARY KEY (_id);


    --
    -- TOC entry 8847 (class 2606 OID 39174)
    -- Name: sm_app sm_app_pkey; Type: CONSTRAINT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.sm_app
        ADD CONSTRAINT sm_app_pkey PRIMARY KEY (_id);


    --
    -- TOC entry 8849 (class 2606 OID 39176)
    -- Name: sm_cat_share sm_cat_share_pkey; Type: CONSTRAINT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.sm_cat_share
        ADD CONSTRAINT sm_cat_share_pkey PRIMARY KEY (_id);


    --
    -- TOC entry 8852 (class 2620 OID 42517)
    -- Name: sm_app sm_app_insert_update_trigger; Type: TRIGGER; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    CREATE TRIGGER sm_app_insert_update_trigger BEFORE INSERT OR UPDATE ON abstract_schema_mapper.sm_app FOR EACH ROW EXECUTE FUNCTION abstract_schema_mapper.insert_update_trigger();


    --
    -- TOC entry 8850 (class 2606 OID 43635)
    -- Name: sm_cat_share _dst_app_id_fk; Type: FK CONSTRAINT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.sm_cat_share
        ADD CONSTRAINT _dst_app_id_fk FOREIGN KEY (_dst_app_id) REFERENCES abstract_schema_mapper.sm_app(_id) ON UPDATE CASCADE ON DELETE CASCADE;


    --
    -- TOC entry 8851 (class 2606 OID 43640)
    -- Name: sm_cat_share _src_app_id_fk; Type: FK CONSTRAINT; Schema: abstract_schema_mapper; Owner: {{ .username }}
    --

    ALTER TABLE ONLY abstract_schema_mapper.sm_cat_share
        ADD CONSTRAINT _src_app_id_fk FOREIGN KEY (_src_app_id) REFERENCES abstract_schema_mapper.sm_app(_id) ON UPDATE CASCADE ON DELETE CASCADE;


    -- Completed on 2023-10-04 13:54:08 +03

    --
    -- PostgreSQL database dump complete
    --

{{- end -}}
