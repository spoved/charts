{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "consul.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "consul.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "consul.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Compute the maximum number of unavailable replicas for the PodDisruptionBudget.
This defaults to (n/2)-1 where n is the number of members of the server cluster.
Special case of replica equaling 3 and allowing a minor disruption of 1 otherwise
use the integer value
Add a special case for replicas=1, where it should default to 0 as well.
*/}}
{{- define "consul.pdb.maxUnavailable" -}}
{{- if eq (int .Values.server.replicas) 1 -}}
{{ 0 }}
{{- else if .Values.server.disruptionBudget.maxUnavailable -}}
{{ .Values.server.disruptionBudget.maxUnavailable -}}
{{- else -}}
{{- if eq (int .Values.server.replicas) 3 -}}
{{- 1 -}}
{{- else -}}
{{- sub (div (int .Values.server.replicas) 2) 1 -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- /*
consul.standard prints the standard Helm labels.
The standard labels are frequently used in metadata.
*/ -}}
{{- define "consul.standard" -}}
app: {{ template "consul.name" . }}
chart: {{ template "consul.chart" . }}
release: {{ .Release.Name }}
heritage: {{ .Release.Service }}
helm.sh/chart: {{ template "consul.chart" . }}
app.kubernetes.io/name: {{ template "consul.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/component: backend
{{- end -}}
