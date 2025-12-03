variable "project_id" {
  description = "GCP project where the dashboards are created."
  type        = string
}

variable "service_name" {
  description = "Istio destination_canonical_service name for which to build dashboards."
  type        = string
}

variable "alignment_period" {
  description = "Alignment period used for aggregating request counts (e.g. 300s)."
  type        = string
  default     = "300s"
}

variable "request_metric_suffix" {
  description = "Suffix of the log-based request metric (e.g. istio-requests-total or istio-availability)."
  type        = string
  default     = "istio-availability"
}

variable "environments" {
  description = "Map of environment name to namespace and alerts_enabled flag."
  type = map(object({
    namespace      = string
    alerts_enabled = bool
  }))
}

variable "endpoints" {
  description = "List of endpoints with method and path/path_regex to graph in the dashboard."
  type = list(object({
    name       = string
    method     = string
    path       = string
    path_regex = string
  }))
}