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
Return the proper nodeSelector
{{ include "peaka.common.nodeSelector" ( dict "nodeSelector" .Values.path.to.the.nodeSelector "global" $.Values.global) }}
*/}}
{{- define "peaka.common.nodeSelector" -}}
  {{- $nodeSelector := .nodeSelector -}}
  {{- if .global -}}
      {{- if .global.nodeSelector -}}
          {{- $nodeSelector = .global.nodeSelector -}}
      {{- end -}}
  {{- end -}}
  {{- if $nodeSelector -}}
nodeSelector:
{{ toYaml $nodeSelector | indent 2 -}}
  {{- end -}}
{{- end -}}

{{/*
Return the proper tolerations
{{ include "peaka.common.tolerations" ( dict "tolerations" .Values.path.to.the.tolerations "global" $.Values.global) }}
*/}}
{{- define "peaka.common.tolerations" -}}
  {{- $tolerations := .tolerations -}}
  {{- if .global -}}
      {{- if .global.tolerations -}}
          {{- $tolerations = .global.tolerations -}}
      {{- end -}}
  {{- end -}}
  {{- if $tolerations -}}
tolerations:
{{ toYaml $tolerations | indent 2 -}}
  {{- end -}}
{{- end -}}

{{/*
Environment variables injected into Peaka services
*/}}
{{- define "peaka.common.envVars" -}}
MINIO_ADDRESS: {{ include "peaka.objectStore.endpoint" . | quote }}
MINIO_ACCESS_KEY: {{ include "peaka.objectStore.accessKey" . | quote }}
MINIO_SECRET_KEY: {{ include "peaka.objectStore.secretKey" .  | quote }}
MINIO_REGION: {{ include "peaka.objectStore.region" . | quote }}

{{- if .Values.externalObjectStore.enabled }}
S3_SINGLE_BUCKET_MODE: {{ .Values.externalObjectStore.singleBucketMode | default "false" | quote }}
S3_BUCKET_NAME: {{ .Values.externalObjectStore.bucket | quote }}
EXPORT_PUBLIC_MINIO_URL: {{ .Values.externalObjectStore.publicUrl | default (include "peaka.objectStore.endpoint" .) | quote }}
{{- else }}
EXPORT_PUBLIC_MINIO_URL: {{ printf "%s%s" (include "peaka.routes.baseUrl" .) (include "peaka.routes.exportPublicPath" .) | quote }}
{{- end }}

STUDIO_DB_ADDRESS: jdbc:postgresql://{{ include "peaka.postgresql.host" . }}:{{ include "peaka.postgresql.port" . }}/{{ include "peaka.postgresql.database" . }}
DB_HOST: {{ include "peaka.postgresql.host" . }}
DB_USERNAME: {{ include "peaka.postgresql.user" . }}
DB_PASSWORD: {{ include "peaka.postgresql.password" . }}
DB_PORT: {{ include "peaka.postgresql.port" . | quote }}
DB_NAME: {{ include "peaka.postgresql.database" . }}
DB_SSL: {{ include "peaka.postgresql.ssl" . | quote }}

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
KAFKA_CONNECT_CLUSTER_NAME: {{ include "peaka.kafka-connect.fullname" . }}
PEAKA_KAFKA_CONNECT_ADDRESS: "http://{{ include "peaka.monitoring-kafka-connect.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:{{ .Values.monitoringKafkaConnect.servicePort }}"

{{- if .Values.temporal.enabled }}
TEMPORAL_ENABLED: "true"
TEMPORAL_TARGET: {{ include "peaka.temporal.fullname" . }}-frontend.{{ .Release.Namespace }}.svc.cluster.local:{{ include "peaka.temporal.frontend.grpcPort" . }}
{{- else }}
TEMPORAL_ENABLED: "false"
{{- end }}

STUDIODB_SCHEMA: studio

TRINO_ADDRESS: jdbc:trino://{{ include "peaka.trino.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:8080
TRINO_JDBC_URL: jdbc:trino://{{ include "peaka.trino.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:8080/?user=trino
{{- if .Values.trino.accessControl }}
TRINO_ACCESS_CONTROL_ENABLED: "true"
{{- else }}
TRINO_ACCESS_CONTROL_ENABLED: "false"
{{- end }}

HIVE_CONFIG_FOLDER: {{ default "/etc/trino/hive_config" .Values.trino.server.hiveConfigPath }}

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
SEARCH_SERVICE_URL: http://{{ include "peaka.fullname" . }}-be-search-service.{{ .Release.Namespace }}.svc.cluster.local:80
SQL_SERVICE_URL: http://{{ include "peaka.fullname" . }}-be-sql-service.{{ .Release.Namespace }}.svc.cluster.local:80
MONITORING_SERVICE_INTERNAL_URL: "http://{{ include "peaka.fullname" . }}-be-monitoring-service.{{ .Release.Namespace }}.svc.cluster.local:80"

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

SHAREDB_MONGO: {{ include "peaka.mongodb.url" . }}

APP_BASEDIR: /metadata
GITHUB_ENABLED: "false"
CONNECTOR_BASEDIR: /run/resource/connector

MATERIALIZED_VIEW_QUERY_TIMEOUT: {{ default 7200   .Values.dataCache.materializedViewQueryTimeout | quote }}

SAMPLE_DATA_APP_ID: {{ default "" .Values.sampleDataAppId | quote }}

BIGTABLE_BUFFER_DB_HOST: {{ include "peaka.postgresql.host" . }}
BIGTABLE_BUFFER_DB_PORT: {{ include "peaka.postgresql.port" . | quote }}
BIGTABLE_BUFFER_DB_USERNAME: {{ include "peaka.postgresql.user" . }}
BIGTABLE_BUFFER_DB_PASSWORD: {{ include "peaka.postgresql.password" . }}
BIGTABLE_BUFFER_DB_NAME: {{ include "peaka.bigtable.database" .  }}

PGVECTOR_DB_HOST: {{ include "peaka.postgresql.host" . }}
PGVECTOR_DB_NAME: {{ include "peaka.postgresql.database" . }}
PGVECTOR_DB_USER: {{ include "peaka.postgresql.user" . }}
PGVECTOR_DB_PASSWORD: {{ include "peaka.postgresql.password" . }}
PGVECTOR_DB_PORT: {{ include "peaka.postgresql.port" . | quote }}
PGVECTOR_DB_SCHEMA: "pgvector"

PAYMENT_ENABLED: "false"
USAGE_MONITORING_ENABLED: "true"
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
PARTNER_API_ENABLED: {{ .Values.partnerApiEnabled | default false | quote }}

PERMIFY_URL: http://{{ include "peaka.permify.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local:{{ .Values.permify.app.server.http.port }}

MANAGEMENT_ENDPOINT_HEALTH_VALIDATE_GROUP_MEMBERSHIP: "false"

{{- if eq (include "peaka.customCA.enabled" .) "true" }}
JAVA_TOOL_OPTIONS: -Djavax.net.ssl.trustStore=/truststore/cacerts -Djavax.net.ssl.trustStorePassword=changeit
NODE_EXTRA_CA_CERTS: /custom-ca-bundle/ca-bundle.crt
{{- end }}
{{- end -}}

{{/*
Set image registry for peaka images
*/}}
{{- define "peaka.image.registry" -}}
{{ .Values.imageRegistry | default "europe-west3-docker.pkg.dev/code2-324814/peaka-service-container-images" }}
{{- end -}}

{{/*
Create imagePullSecret to pull Peaka images
*/}}
{{- define "peaka.imageRegistry.secret" -}}
{{- $registry := "https://europe-west3-docker.pkg.dev" -}}
{{- $username := "_json_key" -}}
{{- $email := "not@val.id" -}}
{{- $password := .Values.peakaContainerRegistryAccessSecret.gcpRegistryAuth.password -}}
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

{{/*
Public sub-path under which the internal MinIO is exposed for query export
downloads. Lives under the service path (reserved for backend routes) to avoid
colliding with front-end paths. The reverse proxy strips this prefix before
reaching MinIO; be-data-rest grafts it onto presigned URLs.
*/}}
{{- define "peaka.routes.exportPublicPath" -}}
/{{ include "peaka.routes.servicePath" . }}/bucket
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
{{- if .Values.postgresql.enabled -}}
{{- printf "%s-%s" .Release.Name "postgres" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "peaka.postgresql.host" -}}
{{- if .Values.postgresql.enabled -}}
{{ include "peaka.postgresql.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local
{{- else -}}
{{- .Values.externalPostgresql.host -}}
{{- end -}}
{{- end -}}

{{- define "peaka.postgresql.port" -}}
{{- if .Values.postgresql.enabled -}}
{{- default 5432 .Values.postgresql.service.port -}}
{{- else -}}
{{- default 5432 .Values.externalPostgresql.port -}}
{{- end -}}
{{- end -}}

{{- define "peaka.postgresql.user" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.username -}}
{{- else -}}
{{- .Values.externalPostgresql.username -}}
{{- end -}}
{{- end -}}

{{- define "peaka.postgresql.database" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.primary.database -}}
{{- else -}}
{{- .Values.externalPostgresql.database -}}
{{- end -}}
{{- end -}}

{{- define "peaka.postgresql.password" -}}
{{- if .Values.postgresql.enabled -}}
{{- .Values.postgresql.auth.password -}}
{{- else -}}
{{- .Values.externalPostgresql.password -}}
{{- end -}}
{{- end -}}

{{- define "peaka.postgresql.passwordSecretKey" -}}
{{- if .Values.postgresql.enabled -}}
{{ .Values.postgresql.auth.secretKeys.userPasswordKey }}
{{- end -}}
{{- end -}}

{{- define "peaka.postgresql.ssl" -}}
{{- if .Values.externalPostgresql.enabled -}}
{{ .Values.externalPostgresql.tls }}
{{- else -}}
false
{{- end -}}
{{- end -}}

{{- define "peaka.hive.name" -}}
{{ include "peaka.fullname" . }}-hive-metastore
{{- end -}}

{{- define "peaka.hive.port" -}}
{{ default 9083 .Values.hiveMetastore.servicePort }}
{{- end -}}

{{/*
Define peaka.objectStore.host
*/}}
{{- define "peaka.objectStore.host" -}}
{{- if .Values.externalObjectStore.enabled -}}
{{- .Values.externalObjectStore.host }}
{{- else -}}
{{- include "peaka.minio.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local
{{- end -}}
{{- end -}}

{{/*
Define peaka.objectStore.region
*/}}
{{- define "peaka.objectStore.region" -}}
{{- if .Values.externalObjectStore.enabled -}}
{{- .Values.externalObjectStore.region }}
{{- else -}}
us-east-1
{{- end -}}
{{- end -}}

{{/*
Define peaka.objectStore.port
*/}}
{{- define "peaka.objectStore.port" -}}
{{- if .Values.externalObjectStore.enabled -}}
{{- default 9000 .Values.externalObjectStore.port }}
{{- else -}}
{{- include "peaka.minio.port" . }}
{{- end -}}
{{- end -}}

{{/*
Define peaka.objectStore.accessKey
*/}}
{{- define "peaka.objectStore.accessKey" -}}
{{- if .Values.externalObjectStore.enabled -}}
{{- .Values.externalObjectStore.accessKey }}
{{- else -}}
{{- include "peaka.minio.accessKey" . }}
{{- end -}}
{{- end -}}

{{/*
Define peaka.objectStore.secretKey
*/}}
{{- define "peaka.objectStore.secretKey" -}}
{{- if .Values.externalObjectStore.enabled -}}
{{- .Values.externalObjectStore.secretKey }}
{{- else -}}
{{- include "peaka.minio.secretKey" . }}
{{- end -}}
{{- end -}}

{{/*
Define peaka.objectStore.scheme
*/}}
{{- define "peaka.objectStore.scheme" -}}
{{- if .Values.externalObjectStore.enabled -}}
{{- ternary "https" "http" .Values.externalObjectStore.tls.enabled }}
{{- else -}}
http
{{- end -}}
{{- end -}}

{{/*
Define peaka.objectStore.endpoint
*/}}
{{- define "peaka.objectStore.endpoint" -}}
{{- printf "%s://%s:%d"
  (include "peaka.objectStore.scheme" .)
  (include "peaka.objectStore.host" .)
  (include "peaka.objectStore.port" . | int)
}}
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
{{- default "peaka_minio" .Values.minio.rootUser }}
{{- end }}

{{/*
Set minio secretKey
*/}}
{{- define "peaka.minio.secretKey" }}
{{- default "peaka_minio123" .Values.minio.rootPassword }}
{{- end }}

{{/*
Returns true if custom CA certificates are configured.
Safe to call even when .Values.global is nil.
*/}}
{{- define "peaka.customCA.enabled" -}}
{{- $certs := (((.Values).global).customCACertificates) -}}
{{- if $certs -}}
true
{{- end -}}
{{- end -}}

{{/*
Init container that imports all custom CA certificates into the Java truststore.
Expects a dict with key "image" (container image with keytool available).
Usage: include "peaka.customCA.initContainer.java" (dict "image" "registry/image:tag")
*/}}
{{- define "peaka.customCA.initContainer.java" -}}
- name: import-custom-ca-truststore
  image: {{ .image }}
  command:
    - sh
    - -c
    - |
      CACERTS=""
      if [ -n "$JAVA_HOME" ] && [ -f "$JAVA_HOME/lib/security/cacerts" ]; then
        CACERTS="$JAVA_HOME/lib/security/cacerts"
      fi
      if [ -z "$CACERTS" ]; then
        CACERTS=$(find / -name cacerts -path "*/security/*" 2>/dev/null | head -1)
      fi
      if [ -n "$CACERTS" ]; then
        echo "Found cacerts at: $CACERTS"
        cp "$CACERTS" /truststore/cacerts
      else
        echo "No existing cacerts found, creating empty truststore"
        keytool -genkeypair -alias temp -keystore /truststore/cacerts -storepass changeit -keypass changeit -dname "CN=temp" -keyalg RSA 2>/dev/null
        keytool -delete -alias temp -keystore /truststore/cacerts -storepass changeit 2>/dev/null
      fi
      chmod 644 /truststore/cacerts
      for cert in /custom-ca-certs/*.crt; do
        BASENAME=$(basename "$cert" .crt)
        COUNT=$(grep -c 'BEGIN CERTIFICATE' "$cert")
        if [ "$COUNT" -le 1 ]; then
          echo "Importing $BASENAME ..."
          keytool -importcert -noprompt \
            -alias "$BASENAME" \
            -keystore /truststore/cacerts \
            -storepass changeit \
            -file "$cert"
        else
          IDX=0
          csplit -z -f /tmp/cert- "$cert" '/-----BEGIN CERTIFICATE-----/' '{*}' 2>/dev/null
          for part in /tmp/cert-*; do
            if grep -q 'BEGIN CERTIFICATE' "$part"; then
              echo "Importing ${BASENAME}-${IDX} ..."
              keytool -importcert -noprompt \
                -alias "${BASENAME}-${IDX}" \
                -keystore /truststore/cacerts \
                -storepass changeit \
                -file "$part"
              IDX=$((IDX + 1))
            fi
          done
          rm -f /tmp/cert-*
        fi
      done
      echo "All custom CA certificates imported into truststore"
  volumeMounts:
    - name: custom-ca-certs
      mountPath: /custom-ca-certs
      readOnly: true
    - name: custom-ca-truststore
      mountPath: /truststore
{{- end -}}

{{/*
Init container that concatenates all custom CA certificates into a single PEM bundle
for Node.js services (NODE_EXTRA_CA_CERTS).
Expects a dict with key "image" (any image with sh + cat).
Usage: include "peaka.customCA.initContainer.node" (dict "image" "registry/image:tag")
*/}}
{{- define "peaka.customCA.initContainer.node" -}}
- name: import-custom-ca-certs
  image: {{ .image }}
  command:
    - sh
    - -c
    - |
      cat /custom-ca-certs/*.crt > /custom-ca-bundle/ca-bundle.crt
      echo "Custom CA bundle created with $(grep -c 'BEGIN CERTIFICATE' /custom-ca-bundle/ca-bundle.crt) certificate(s)"
  volumeMounts:
    - name: custom-ca-certs
      mountPath: /custom-ca-certs
      readOnly: true
    - name: custom-ca-bundle
      mountPath: /custom-ca-bundle
{{- end -}}

{{/*
Hive metastore database connection - always the chart's single PostgreSQL.
*/}}
{{- define "peaka.metastore.host" -}}
{{- include "peaka.postgresql.host" . -}}
{{- end -}}

{{- define "peaka.metastore.dbName" -}}
peaka_metastore_db
{{- end -}}

{{- define "peaka.metastore.user" -}}
{{- include "peaka.postgresql.user" . -}}
{{- end -}}

{{- define "peaka.metastore.password" -}}
{{- include "peaka.postgresql.password" . -}}
{{- end -}}

{{- define "peaka.metastore.port" -}}
{{- include "peaka.postgresql.port" . -}}
{{- end -}}

{{- define "peaka.metastore.connection" -}}
postgresql
{{- end -}}

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
Set peaka.mongodb.host
*/}}
{{- define "peaka.mongodb.host" -}}
{{- if .Values.externalMongoDB.enabled -}}
{{ .Values.externalMongoDB.host }}
{{- else -}}
{{- printf "%s-%s" .Release.Name "mongodb" | trunc 63 | trimSuffix "-" -}}.{{ .Release.Namespace }}.svc.cluster.local
{{- end -}}
{{- end -}}

{{/*
Set peaka.mongodb.port
*/}}
{{- define "peaka.mongodb.port" -}}
{{- if .Values.externalMongoDB.enabled -}}
{{ default 27017 .Values.externalMongoDB.port }}
{{- else -}}
{{ default 27017 .Values.mongodb.service.ports.mongodb }}
{{- end -}}
{{- end -}}

{{/*
Set peaka.mongodb.username
*/}}
{{- define "peaka.mongodb.username" -}}
{{- if .Values.externalMongoDB.enabled -}}
{{ .Values.externalMongoDB.auth.username }}
{{- else -}}
{{ .Values.mongodb.auth.username }}
{{- end -}}
{{- end -}}

{{/*
Set peaka.mongodb.password
*/}}
{{- define "peaka.mongodb.password" -}}
{{- if .Values.externalMongoDB.enabled -}}
{{ .Values.externalMongoDB.auth.password }}
{{- else -}}
{{ .Values.mongodb.auth.password }}
{{- end -}}
{{- end -}}

{{/*
Set peaka.mongodb.tls
Determine if TLS is enabled
*/}}
{{- define "peaka.mongodb.tls" -}}
{{- if .Values.externalMongoDB.enabled -}}
{{- .Values.externalMongoDB.tls.enabled | default false -}}
{{- else -}}
{{- .Values.mongodb.tls.enabled | default false -}}
{{- end -}}
{{- end -}}

{{/*
Set peaka.mongodb.scheme
Returns mongodb+srv if srv is enabled, otherwise mongodb
*/}}
{{- define "peaka.mongodb.scheme" -}}
{{- if and .Values.externalMongoDB.enabled .Values.externalMongoDB.srv -}}
{{- printf "mongodb+srv" -}}
{{- else -}}
{{- printf "mongodb" -}}
{{- end -}}
{{- end -}}

{{/*
Set peaka.mongodb.url
Format: mongodb[+srv]://[username:password@]host[:port][?param1&param2...]
If externalMongoDB.auth.connection_uri is set, it takes precedence over all other parameters.
If externalMongoDB.srv is true, mongodb+srv scheme is used and port is omitted.
Query parameters (tls, additionalParameters) are collected into a list and
joined with '&', then prefixed with '?' — so '?' vs '&' is handled automatically.
*/}}
{{- define "peaka.mongodb.url" -}}
{{- if and .Values.externalMongoDB.enabled .Values.externalMongoDB.auth.connection_uri -}}
{{- .Values.externalMongoDB.auth.connection_uri -}}
{{- else -}}
{{- $scheme := include "peaka.mongodb.scheme" . -}}
{{- $user   := include "peaka.mongodb.username" . -}}
{{- $pass   := include "peaka.mongodb.password" . -}}
{{- $host   := include "peaka.mongodb.host" . -}}
{{- $port   := include "peaka.mongodb.port" . -}}
{{- $tls    := include "peaka.mongodb.tls" . -}}
{{- $srv    := and .Values.externalMongoDB.enabled .Values.externalMongoDB.srv -}}

{{- $auth := "" -}}
{{- if and $user $pass -}}
  {{- $auth = printf "%s:%s@" $user $pass -}}
{{- end -}}

{{/* ── Collect all query parameters into a list ── */}}
{{- $params := list -}}

{{/* TLS param (only meaningful when not using +srv, since srv implies TLS) */}}
{{- if and (not $srv) (eq $tls "true") -}}
  {{- $params = append $params "tls=true" -}}
{{- end -}}

{{/* additionalParameters from values */}}
{{- range .Values.externalMongoDB.additionalParameters -}}
  {{- $params = append $params . -}}
{{- end -}}

{{/* Build the query string: ?p1&p2&p3 — or empty string if no params */}}
{{- $queryString := "" -}}
{{- if $params -}}
  {{- $queryString = printf "?%s" (join "&" $params) -}}
{{- end -}}

{{/* Assemble final URL */}}
{{- if $srv -}}
  {{- printf "%s://%s%s/%s" $scheme $auth $host $queryString -}}
{{- else -}}
  {{- printf "%s://%s%s:%s/%s" $scheme $auth $host $port $queryString -}}
{{- end -}}
{{- end -}}
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

{{- define "peaka.bigtable.database" -}}
{{- if .Values.externalPostgresql.enabled -}}
{{ .Values.externalPostgresql.bigtable.database }}
{{- else -}}
{{ .Values.postgresql.bigtable.database }}
{{- end -}}
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
{{- .Release.Name -}}-kafka-connect
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

{{/*
Define the peaka.monitoring-kafka-connect.fullname template with .Release.Name and "monitoring-kafka-connect"
*/}}
{{- define "peaka.monitoring-kafka-connect.fullname" -}}
{{- printf "%s-%s" .Release.Name "monitoring-kafka-connect" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified kafka headless name.
*/}}
{{- define "peaka.monitoring-kafka-connect.kafka-headless.fullname" -}}
{{- $name := "monitoring-kafka-headless" -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Set peaka.monitoring-kafka-connect.groupId to Release Name
*/}}
{{- define "peaka.monitoring-kafka-connect.groupId" -}}
{{- .Release.Name -}}-monitoring-kafka-connect
{{- end -}}

{{/*
Create a default fully qualified schema registry name for monitoring kafka connect.
*/}}
{{- define "peaka.monitoring-kafka-connect.cp-schema-registry.fullname" -}}
{{- printf "%s-%s" .Release.Name "monitoring-kafka-connect-schema-registry" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "peaka.monitoring-kafka-connect.cp-schema-registry.service-name" -}}
{{- if (index .Values "monitoringKafkaConnect" "cp-schema-registry" "url") -}}
{{- printf "%s" (index .Values "monitoringKafkaConnect" "cp-schema-registry" "url") -}}
{{- else -}}
{{- printf "http://%s:8081" (include "peaka.monitoring-kafka-connect.cp-schema-registry.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "peaka.trino.fullname" -}}
{{- printf "%s-%s" .Release.Name "trino" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{- define "peaka.trino.catalog" -}}
{{ template "peaka.trino.fullname" . }}-catalog
{{- end -}}

{{- define "peaka.trino.keytab" -}}
{{ template "peaka.trino.fullname" . }}-kerberos-keytab
{{- end -}}

{{- define "peaka.trino.worker" -}}
{{- printf "%s-%s" .Release.Name "trino-worker" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "peaka.trino.coordinator" -}}
{{- printf "%s-%s" .Release.Name "trino-coordinator" | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
Expand the name of Temporal.
*/}}
{{- define "peaka.temporal.name" -}}
{{- default (printf "%s-temporal" .Chart.Name) .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name for Temporal.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "peaka.temporal.fullname" -}}
{{- if .Values.temporal.fullnameOverride -}}
{{- .Values.temporal.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default (printf "%s-temporal" .Chart.Name ) .Values.temporal.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create Temporal name and version as used by the chart label.
*/}}
{{- define "peaka.temporal.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create the name of the Temporal service account
*/}}
{{- define "peaka.temporal.serviceAccountName" -}}
{{ default (include "peaka.temporal.fullname" .) .Values.temporal.serviceAccount.name }}
{{- end -}}

{{/*
Define the Temporal service account as needed
*/}}
{{- define "peaka.temporal.serviceAccount" -}}
{{- if .Values.temporal.serviceAccount.create -}}
serviceAccountName: {{ include "peaka.temporal.serviceAccountName" . }}
{{- end -}}
{{- end -}}

{{/*
Create a default fully qualified Temporal component name from the full temporal name and a component name.
We truncate the full name at 63 - 1 (last dash) - len(component name) chars because some Kubernetes name fields are limited to this (by the DNS naming spec)
and we want to make sure that the component is included in the name.
*/}}
{{- define "peaka.temporal.componentname" -}}
{{- $global := index . 0 -}}
{{- $component := index . 1 | trimPrefix "-" -}}
{{- printf "%s-%s" (include "peaka.temporal.fullname" $global | trunc (sub 62 (len $component) | int) | trimSuffix "-" ) $component | trimSuffix "-" -}}
{{- end -}}

{{/*
Call nested templates.
Source: https://stackoverflow.com/a/52024583/3027614
*/}}
{{- define "peaka.temporal.call-nested" }}
{{- $dot := index . 0 }}
{{- $subchart := index . 1 }}
{{- $template := index . 2 }}
{{- include $template (dict "Chart" (dict "Name" $subchart) "Values" (index $dot.Values $subchart) "Release" $dot.Release "Capabilities" $dot.Capabilities) }}
{{- end }}

{{- define "peaka.temporal.frontend.grpcPort" -}}
{{- if $.Values.temporal.server.frontend.service.port -}}
{{- $.Values.temporal.server.frontend.service.port -}}
{{- else -}}
{{- 7233 -}}
{{- end -}}
{{- end -}}

{{- define "peaka.temporal.frontend.membershipPort" -}}
{{- if $.Values.temporal.server.frontend.service.membershipPort -}}
{{- $.Values.temporal.server.frontend.service.membershipPort -}}
{{- else -}}
{{- 6933 -}}
{{- end -}}
{{- end -}}

{{- define "peaka.temporal.history.grpcPort" -}}
{{- if $.Values.temporal.server.history.service.port -}}
{{- $.Values.temporal.server.history.service.port -}}
{{- else -}}
{{- 7234 -}}
{{- end -}}
{{- end -}}

{{- define "peaka.temporal.history.membershipPort" -}}
{{- if $.Values.temporal.server.history.service.membershipPort -}}
{{- $.Values.temporal.server.history.service.membershipPort -}}
{{- else -}}
{{- 6934 -}}
{{- end -}}
{{- end -}}

{{- define "peaka.temporal.matching.grpcPort" -}}
{{- if $.Values.temporal.server.matching.service.port -}}
{{- $.Values.temporal.server.matching.service.port -}}
{{- else -}}
{{- 7235 -}}
{{- end -}}
{{- end -}}

{{- define "peaka.temporal.matching.membershipPort" -}}
{{- if $.Values.temporal.server.matching.service.membershipPort -}}
{{- $.Values.temporal.server.matching.service.membershipPort -}}
{{- else -}}
{{- 6935 -}}
{{- end -}}
{{- end -}}

{{- define "peaka.temporal.worker.grpcPort" -}}
{{- if $.Values.temporal.server.worker.service.port -}}
{{- $.Values.temporal.server.worker.service.port -}}
{{- else -}}
{{- 7239 -}}
{{- end -}}
{{- end -}}

{{- define "peaka.temporal.worker.membershipPort" -}}
{{- if $.Values.temporal.server.worker.service.membershipPort -}}
{{- $.Values.temporal.server.worker.service.membershipPort -}}
{{- else -}}
{{- 6939 -}}
{{- end -}}
{{- end -}}

{{- define "peaka.temporal.persistence.schema" -}}
{{- if eq . "default" -}}
{{- print "temporal" -}}
{{- else -}}
{{- print . -}}
{{- end -}}
{{- end -}}

{{- define "peaka.temporal.persistence.driver" -}}
{{- print "sql" -}}
{{- end -}}

{{- define "peaka.temporal.persistence.cassandra.hosts" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $storeConfig := index $global.Values.temporal.server.config.persistence $store -}}
{{- if $storeConfig.cassandra.hosts -}}
{{- $storeConfig.cassandra.hosts | join "," -}}
{{- else if and $global.Values.temporal.cassandra.enabled (eq (include "peaka.temporal.persistence.driver" (list $global $store)) "cassandra") -}}
{{- include "peaka.temporal.cassandra.hosts" $global -}}
{{- else -}}
{{- required (printf "Please specify cassandra hosts for %s store" $store) $storeConfig.cassandra.hosts -}}
{{- end -}}
{{- end -}}

{{- define "peaka.temporal.persistence.cassandra.port" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $storeConfig := index $global.Values.temporal.server.config.persistence $store -}}
{{- if $storeConfig.cassandra.port -}}
{{- $storeConfig.cassandra.port -}}
{{- else if and $global.Values.temporal.cassandra.enabled (eq (include "peaka.temporal.persistence.driver" (list $global $store)) "cassandra") -}}
{{- $global.Values.temporal.cassandra.config.ports.cql -}}
{{- else -}}
{{- required (printf "Please specify cassandra port for %s store" $store) $storeConfig.cassandra.port -}}
{{- end -}}
{{- end -}}

{{- define "peaka.temporal.persistence.cassandra.secretName" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $storeConfig := index $global.Values.temporal.server.config.persistence $store -}}
{{- if $storeConfig.cassandra.existingSecret -}}
{{- $storeConfig.cassandra.existingSecret -}}
{{- else if $storeConfig.cassandra.password -}}
{{- include "peaka.temporal.componentname" (list $global (printf "%s-store" $store)) -}}
{{- else -}}
{{/* Cassandra password is optional, but we will create an empty secret for it */}}
{{- include "peaka.temporal.componentname" (list $global (printf "%s-store" $store)) -}}
{{- end -}}
{{- end -}}

{{- define "peaka.temporal.persistence.cassandra.secretKey" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $storeConfig := index $global.Values.temporal.server.config.persistence $store -}}
{{/* Cassandra password is optional, but we will create an empty secret for it */}}
{{- print "password" -}}
{{- end -}}

{{- define "peaka.temporal.persistence.sql.database" -}}
{{- $root := index . 0 -}}
{{- $store := index . 1 -}}
{{- if eq $store "default" -}}
{{- $root.Values.temporal.server.config.persistence.default.sql.database }}
{{- else if eq $store "visibility" -}}
{{- $root.Values.temporal.server.config.persistence.visibility.sql.database }}
{{- else -}}
{{- fail (printf "Unknown database type: %s" $store) -}}
{{- end -}}
{{- end -}}

{{- define "peaka.temporal.persistence.sql.driver" -}}
postgres12
{{- end -}}

{{- define "peaka.temporal.persistence.sql.host" -}}
{{ include "peaka.postgresql.host" . }}
{{- end -}}

{{- define "peaka.temporal.persistence.sql.port" -}}
{{ include "peaka.postgresql.port" . }}
{{- end -}}

{{- define "peaka.temporal.persistence.sql.user" -}}
{{ include "peaka.postgresql.user" . }}
{{- end -}}

{{- define "peaka.temporal.persistence.sql.password" -}}
{{ include "peaka.postgresql.password" . }}
{{- end -}}

{{- define "peaka.temporal.persistence.sql.secretName" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- $storeConfig := index $global.Values.temporal.server.config.persistence $store -}}
{{- if $storeConfig.sql.existingSecret -}}
{{- $storeConfig.sql.existingSecret -}}
{{- else if $storeConfig.sql.password -}}
{{- include "peaka.temporal.componentname" (list $global (printf "%s-store" $store)) -}}
{{- else if and $global.Values.temporal.mysql.enabled (and (eq (include "peaka.temporal.persistence.driver" (list $global $store)) "sql") (eq (include "peaka.temporal.persistence.sql.driver" (list $global $store)) "mysql8")) -}}
{{- include "peaka.temporal.call-nested" (list $global "mysql" "mysql.secretName") -}}
{{- else if and $global.Values.temporal.postgresql.enabled (and (eq (include "peaka.temporal.persistence.driver" (list $global $store)) "sql") (eq (include "peaka.temporal.persistence.sql.driver" (list $global $store)) "postgres12")) -}}
{{- include "peaka.temporal.componentname" (list $global (printf "%s-store" $store)) -}}
{{- else -}}
{{- required (printf "Please specify sql password or existing secret for %s store" $store) $storeConfig.sql.existingSecret -}}
{{- end -}}
{{- end -}}

{{- define "peaka.temporal.persistence.sql.secretKey" -}}
{{- print "password" -}}
{{- end -}}

{{- define "peaka.temporal.persistence.secretName" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- include (printf "peaka.temporal.persistence.%s.secretName" (include "peaka.temporal.persistence.driver" (list $global $store))) (list $global $store) -}}
{{- end -}}

{{- define "peaka.temporal.persistence.secretKey" -}}
{{- $global := index . 0 -}}
{{- $store := index . 1 -}}
{{- include (printf "peaka.temporal.persistence.%s.secretKey" (include "peaka.temporal.persistence.driver" (list $global $store))) (list $global $store) -}}
{{- end -}}

{{/*
All Temporal Cassandra hosts.
*/}}
{{- define "peaka.temporal.cassandra.hosts" -}}
{{- range $i := (until (int .Values.temporal.cassandra.config.cluster_size)) }}
{{- $cassandraName := include "peaka.temporal.call-nested" (list $ "cassandra" "cassandra.fullname") -}}
{{- printf "%s.%s.svc.cluster.local," $cassandraName $.Release.Namespace -}}
{{- end }}
{{- end -}}

{{/*
The first Temporal Cassandra host in the stateful set.
*/}}
{{- define "peaka.temporal.cassandra.host" -}}
{{- $cassandraName := include "peaka.temporal.call-nested" (list . "cassandra" "cassandra.fullname") -}}
{{- printf "%s.%s.svc.cluster.local" $cassandraName .Release.Namespace -}}
{{- end -}}

{{/*
Based on Bitnami charts method
Renders a value that contains template.
Usage:
{{ include "common.tplvalues.render" ( dict "value" .Values.path.to.the.Value "context" $) }}
*/}}
{{- define "peaka.temporal.common.tplvalues.render" -}}
    {{- if typeIs "string" .value }}
        {{- tpl .value .context }}
    {{- else }}
        {{- tpl (.value | toYaml) .context }}
    {{- end }}
{{- end -}}


{{/*
Define the peaka.permify.fullname template with .Release.Name and "permify"
*/}}
{{- define "peaka.permify.fullname" -}}
{{- printf "%s-%s" .Release.Name "permify" | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{/*
Define the peaka.pgcat.fullname using "peaka.fullname"
*/}}
{{- define "peaka.pgcat.fullname" -}}
{{- printf "%s-pgcat" (include "peaka.fullname" .) -}}
{{- end -}}

{{- define "peaka.pgcat.port" -}}
{{- .Values.pgcat.configuration.general.port -}}
{{- end -}}

{{- define "peaka.dbc.url" -}}
{{- default .Values.accessUrl.domain .Values.accessUrl.dbcDomain -}}
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

{{/*
Define hive init script
*/}}
{{- define  "peaka.postgresql.initHive" -}}
CREATE DATABASE {{ include "peaka.metastore.dbName" . }} WITH OWNER {{ include "peaka.postgresql.user" . }} ;
{{- end -}}

{{/*
Define peaka role
*/}}
{{- define "peaka.postgresql.initRole" -}}
DO
$$
BEGIN
  IF NOT EXISTS (
    SELECT FROM pg_catalog.pg_roles WHERE rolname = '{{ include "peaka.postgresql.user" . }}'
  ) THEN
    CREATE ROLE {{ include "peaka.postgresql.user" . }}
      WITH LOGIN
      CREATEDB
      PASSWORD '{{ include "peaka.postgresql.password" . }}';
  END IF;
END
$$;
{{- end -}}

{{/*
Define permify init script
*/}}
{{- define "peaka.postgresql.initPermify" -}}
CREATE DATABASE {{ .Values.permify.app.database.name }} WITH OWNER {{ include "peaka.postgresql.user" . }} ;
{{- end -}}

{{/*
Define peaka db init script
*/}}
{{- define "peaka.postgresql.initPeaka" -}}
DROP DATABASE IF EXISTS {{ include "peaka.postgresql.database" . }} ;
CREATE DATABASE {{ include "peaka.postgresql.database" . }}  WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_US.UTF-8';
ALTER DATABASE {{ include "peaka.postgresql.database" . }}  OWNER TO {{ include "peaka.postgresql.user" . }} ;
{{- end -}}

{{/*
Define peaka bigtable db init script
*/}}
{{- define "peaka.postgresql.initPeakabigtable" -}}
DROP DATABASE IF EXISTS {{ include "peaka.bigtable.database" . }} ;
CREATE DATABASE {{ include "peaka.bigtable.database" . }}  WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_US.UTF-8';
ALTER DATABASE {{ include "peaka.bigtable.database" . }}  OWNER TO {{ include "peaka.postgresql.user" . }} ;
{{- end -}}

{{/*
Define vector extension init script
*/}}
{{- define "peaka.postgresql.initPgvector" -}}
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
{{- end -}}

{{/*
Define temporal database init script
*/}}
{{- define "peaka.postgresql.initTemporal" -}}
CREATE DATABASE {{ include "peaka.temporal.persistence.sql.database" (list $ "default") }} WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_US.utf8';
ALTER DATABASE {{ include "peaka.temporal.persistence.sql.database" (list $ "default") }} OWNER TO {{ include "peaka.postgresql.user" . }};
{{- end -}}

{{/*
Define temporal visibility database init script
*/}}
{{- define "peaka.postgresql.initTemporalVisibility" -}}
CREATE DATABASE {{ include "peaka.temporal.persistence.sql.database" (list $ "visibility") }} WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_US.utf8';
ALTER DATABASE {{ include "peaka.temporal.persistence.sql.database" (list $ "visibility") }} OWNER TO {{ include "peaka.postgresql.user" . }};
{{- end -}}

{{/*
Define studio schema init script
*/}}
{{- define "peaka.postgresql.initStudio" -}}
CREATE SCHEMA IF NOT EXISTS studio;
ALTER SCHEMA studio OWNER TO {{ include "peaka.postgresql.user" . }} ;
DROP FUNCTION IF EXISTS studio.gen_random_uuid();

CREATE OR REPLACE FUNCTION studio.gen_random_uuid(
  )
    RETURNS uuid
    LANGUAGE 'c'
    COST 1
    VOLATILE PARALLEL SAFE
AS '$libdir/pgcrypto', 'pg_random_uuid'
;

ALTER FUNCTION studio.gen_random_uuid() OWNER TO {{ include "peaka.postgresql.user" . }} ;

{{- end -}}

{{/*
Define abstract schema mapper init script
*/}}
{{- define "peaka.postgresql.initASM" -}}
{{- tpl (.Files.Get "files/asm-schema.sql" | trim) . -}}
{{- end -}}
