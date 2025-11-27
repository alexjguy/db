variable "project_id" {
  type = string
}

variable "environments" {
  description = "Map of environment name to namespace + alert toggle"
  type = map(object({
    namespace      = string
    alerts_enabled = bool
  }))
  default = {}
}

variable "notification_channels" {
  description = "List of notification channel IDs for alerts (not used yet, reserved)."
  type        = list(string)
  default     = []
}

variable "cuj" {
  description = "CUJ id (e.g. cuj1) used in naming."
  type        = string
}

variable "canonical_service" {
  description = "destination_canonical_service from Istio / ASM logs."
  type        = string
}

variable "endpoints" {
  description = <<-EOT
  List of endpoint SLO definitions for this canonical service.

  Each endpoint:
    name   - unique name per service (e.g. login, get-profile)

    # filters
    methods = list of HTTP methods; [] = all
    paths   = list of normalized paths (as they appear in logs); [] = all

    # availability SLO
    good_status_classes  - status classes treated as GOOD ("2","3" -> 2xx,3xx)
    total_status_classes - status classes in TOTAL; [] = all
    availability_goal    - 0 means "no availability SLO for this endpoint"
    rolling_period_days  - window length for both SLO types

    # latency SLO
    latency_status_classes - which classes to include in latency SLO (["2","3"], etc.)
    latency_goal           - 0 means "no latency SLO"
    latency_threshold_ms   - threshold in ms (e.g. 300); 0 => latency SLO disabled
  EOT

  type = list(object({
    name   = string

    methods = list(string)
    paths   = list(string)

    good_status_classes  = list(string)
    total_status_classes = list(string)
    availability_goal    = number
    rolling_period_days  = number

    latency_status_classes = list(string)
    latency_goal           = number
    latency_threshold_ms   = number
  }))
}