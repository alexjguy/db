
resource "google_logging_metric" "istio_requests" {
  project     = var.project_id
  name        = "istio_${var.cuj}_server_requests"
  description = "Istio/ASM server access log requests, labeled by canonical service, method, path and status class."

  filter = <<-EOT
    resource.type="k8s_container"
    logName="projects/${var.project_id}/logs/server-accesslog-stackdriver"
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"

    labels {
      key         = "destination_canonical_service"
      value_type  = "STRING"
      description = "Istio canonical service."
    }

    labels {
      key         = "http_method"
      value_type  = "STRING"
      description = "HTTP request method."
    }

    labels {
      key         = "http_path"
      value_type  = "STRING"
      description = "Normalized HTTP path (no query)."
    }

    labels {
      key         = "status_class"
      value_type  = "STRING"
      description = "HTTP status class: first digit of status (1..5)."
    }

    labels {
      key         = "namespace"
      value_type  = "STRING"
      description = "Kubernetes namespace (environment)."
    }
  }

  # Adjust the expressions if your log schema differs
  label_extractors = {
    destination_canonical_service = "labels[\"destination_canonical_service\"]"
    http_method                   = "httpRequest.requestMethod"
    http_path                     = "REGEXP_EXTRACT(httpRequest.requestUrl, \"https?://[^/]+([^?]+)\")"
    status_class                  = "REGEXP_EXTRACT(string(httpRequest.status), \"^(\\\\d)\")"
    namespace                     = "resource.labels[\"namespace_name\"]"
  }
}

resource "google_logging_metric" "istio_latency" {
  project     = var.project_id
  name        = "istio_${var.cuj}_server_latency"
  description = "Istio/ASM server access log latency, labeled by canonical service, method, path and status class."

  filter = <<-EOT
    resource.type="k8s_container"
    logName="projects/${var.project_id}/logs/server-accesslog-stackdriver"
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "DISTRIBUTION"
    unit        = "s"

    labels {
      key         = "destination_canonical_service"
      value_type  = "STRING"
      description = "Istio canonical service."
    }

    labels {
      key         = "http_method"
      value_type  = "STRING"
      description = "HTTP request method."
    }

    labels {
      key         = "http_path"
      value_type  = "STRING"
      description = "Normalized HTTP path (no query)."
    }

    labels {
      key         = "status_class"
      value_type  = "STRING"
      description = "HTTP status class: first digit of status (1..5)."
    }

    labels {
      key         = "namespace"
      value_type  = "STRING"
      description = "Kubernetes namespace (environment)."
    }
  }

  # If you don't have httpRequest.latency, swap this to your real field
  value_extractor = "EXTRACT_DURATION(httpRequest.latency)"

  label_extractors = {
    destination_canonical_service = "labels[\"destination_canonical_service\"]"
    http_method                   = "httpRequest.requestMethod"
    http_path                     = "REGEXP_EXTRACT(httpRequest.requestUrl, \"https?://[^/]+([^?]+)\")"
    status_class                  = "REGEXP_EXTRACT(string(httpRequest.status), \"^(\\\\d)\")"
    namespace                     = "resource.labels[\"namespace_name\"]"
  }
}

########################################
# Monitoring custom services (per env)
########################################

resource "google_monitoring_custom_service" "service" {
  for_each = var.environments

  project      = var.project_id
  service_id   = "istio-${var.canonical_service}-${each.key}-${var.cuj}"
  display_name = "${var.canonical_service} (${each.key}, ${var.cuj})"

  telemetry {
    resource_name = "k8s_container"
  }
}

########################################
# Flatten env + endpoint into rules
########################################

locals {
  # One rule per (env, endpoint)
  rules = {
    for env, env_cfg in var.environments :
    for ep in var.endpoints :
    "${env}:${ep.name}" => {
      env         = env
      namespace   = env_cfg.namespace
      alerts_enabled = env_cfg.alerts_enabled

      endpoint_name = ep.name

      methods = ep.methods
      paths   = ep.paths

      good_status_classes  = ep.good_status_classes
      total_status_classes = ep.total_status_classes
      availability_goal    = ep.availability_goal
      rolling_period_days  = ep.rolling_period_days

      latency_status_classes = ep.latency_status_classes
      latency_goal           = ep.latency_goal
      latency_threshold_ms   = ep.latency_threshold_ms
    }
  }

  request_metric_type = "logging.googleapis.com/user/${google_logging_metric.istio_requests.name}"
  latency_metric_type = "logging.googleapis.com/user/${google_logging_metric.istio_latency.name}"
}

# Split into availability / latency subsets
locals {
  availability_rules = {
    for k, v in local.rules :
    k => v if v.availability_goal > 0
  }

  latency_rules = {
    for k, v in local.rules :
    k => v if v.latency_goal > 0 && v.latency_threshold_ms > 0
  }
}

########################################
# Filter builders
########################################

# Base per-rule filter: canonical service + namespace + methods/paths
locals {
  base_filters = {
    for k, v in local.rules :
    k => join(" AND ", compact([
      "resource.type=\"k8s_container\"",
      "metric.label.\"destination_canonical_service\"=\"${var.canonical_service}\"",
      "metric.label.\"namespace\"=\"${v.namespace}\"",

      length(v.methods) > 0 ?
        "(${join(" OR ", [for m in v.methods : "metric.label.\"http_method\"=\"${m}\""])})"
        : "",

      length(v.paths) > 0 ?
        "(${join(" OR ", [for p in v.paths : "metric.label.\"http_path\"=\"${p}\""])})"
        : ""
    ]))
  }
}

# Availability good/total filters
locals {
  availability_good_filters = {
    for k, v in local.availability_rules :
    k => join(" AND ", compact([
      "metric.type=\"${local.request_metric_type}\"",
      local.base_filters[k],

      length(v.good_status_classes) > 0 ?
        "(${join(" OR ", [for c in v.good_status_classes : "metric.label.\"status_class\"=\"${c}\""])})"
        : ""
    ]))
  }

  availability_total_filters = {
    for k, v in local.availability_rules :
    k => join(" AND ", compact([
      "metric.type=\"${local.request_metric_type}\"",
      local.base_filters[k],

      length(v.total_status_classes) > 0 ?
        "(${join(" OR ", [for c in v.total_status_classes : "metric.label.\"status_class\"=\"${c}\""])})"
        : ""
    ]))
  }
}

# Latency filters
locals {
  latency_filters = {
    for k, v in local.latency_rules :
    k => join(" AND ", compact([
      "metric.type=\"${local.latency_metric_type}\"",
      local.base_filters[k],

      length(v.latency_status_classes) > 0 ?
        "(${join(" OR ", [for c in v.latency_status_classes : "metric.label.\"status_class\"=\"${c}\""])})"
        : ""
    ]))
  }
}

########################################
# SLO resources
########################################

resource "google_monitoring_slo" "availability" {
  for_each = local.availability_rules

  project = var.project_id
  service = google_monitoring_custom_service.service[each.value.env].name

  slo_id       = "${var.cuj}-${each.value.env}-${each.value.endpoint_name}-availability"
  display_name = "Availability ${each.value.availability_goal * 100}% - ${var.cuj} - ${each.value.env} - ${each.value.endpoint_name}"

  goal                = each.value.availability_goal
  rolling_period_days = each.value.rolling_period_days

  request_based_sli {
    good_total_ratio {
      good_service_filter  = local.availability_good_filters[each.key]
      total_service_filter = local.availability_total_filters[each.key]
    }
  }
}

resource "google_monitoring_slo" "latency" {
  for_each = local.latency_rules

  project = var.project_id
  service = google_monitoring_custom_service.service[each.value.env].name

  slo_id       = "${var.cuj}-${each.value.env}-${each.value.endpoint_name}-latency"
  display_name = "Latency ${each.value.latency_goal * 100}% - ${var.cuj} - ${each.value.env} - ${each.value.endpoint_name}"

  goal                = each.value.latency_goal
  rolling_period_days = each.value.rolling_period_days

  request_based_sli {
    latency {
      threshold  = each.value.latency_threshold_ms / 1000
      percentile = 95
      service_filter = local.latency_filters[each.key]
    }
  }
}