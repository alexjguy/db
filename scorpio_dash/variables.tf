variable "project_id" {
  description = "GCP project where the dashboard lives"
  type        = string
}

variable "env_name" {
  description = "Environment name used in metric.type (ft1, sit1, etc.)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the service"
  type        = string
}

variable "service_name" {
  description = "Istio canonical service name (destination_canonical_service)"
  type        = string
}

variable "alignment_period" {
  description = "Alignment period for charts (e.g. 300s for 5 minutes)"
  type        = string
  default     = "300s"
}

variable "endpoints" {
  description = <<EOT
List of endpoints to graph.

Each element:
- name       : short label for the widget title
- method     : HTTP method (GET/POST/PUT/OPTIONS/...)
- path       : exact http_path label to match (empty string if using path_regex)
- path_regex : regex for http_path (empty string if using exact path)
EOT

  type = list(object({
    name       = string
    method     = string
    path       = string
    path_regex = string
  }))
}