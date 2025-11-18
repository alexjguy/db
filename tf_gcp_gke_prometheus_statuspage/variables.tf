variable "project_id" {
  type        = string
  description = "GCP project id where the dashboards will live"
}

# env -> { namespace, cluster, alerts_enabled }
variable "x_environments" {
  type = map(object({
    namespace      = string
    cluster        = string
    alerts_enabled = bool
  }))
}

variable "cuj_workloads" {
  type = map(object({
    name      = string        # human CUJ name, e.g. "customer-success"
    workloads = list(string)  # services in that CUJ
  }))
  description = "Map CUJ id -> { name, workloads }"
}