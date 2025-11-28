locals {

  labels = [
    {
      key         = "destination_canonical_service"
      value_type  = "STRING"
      description = "Istio canonical service."
    },
    {
      key         = "http_method"
      value_type  = "STRING"
      description = "HTTP request method."
    },
    {
      key         = "http_path"
      value_type  = "STRING"
      description = "Normalized HTTP path (no query)."
    },
    {
      key         = "status_class"
      value_type  = "STRING"
      description = "HTTP status class (first digit)."
    },
    {
      key         = "namespace"
      value_type  = "STRING"
      description = "Kubernetes namespace (environment)."
    },
  ]

  label_extractors = {
    destination_canonical_service = "labels[\"destination_canonical_service\"]"
    http_method                   = "httpRequest.requestMethod"
    http_path                     = "REGEXP_EXTRACT(httpRequest.requestUrl, \"https?://[^/]+([^?]+)\")"
    status_class                  = "REGEXP_EXTRACT(string(httpRequest.status), \"^(\\\\d)\")"
    namespace                     = "resource.labels[\"namespace_name\"]"
  }

  # base log filter for metrics (per env)
  base_log_filter = {
    for env_key, env in var.environments :
    env_key => <<-EOT
resource.type="k8s_container"
resource.labels.namespace_name="${env.namespace}"
logName="projects/${var.project_id}/logs/server-accesslog-stackdriver"
EOT
  }

  # metric types per env
  request_metric_type = {
    for env_name, _ in var.environments :
    env_name => "logging.googleapis.com/user/${env_name}_istio-requests-total_${var.service_name}"
  }

  latency_metric_type = {
    for env_name, _ in var.environments :
    env_name => "logging.googleapis.com/user/${env_name}_istio-latency_${var.service_name}"
  }

  # shared prefix for availability SLO filters (per env)
  availability_filter_prefix = {
    for env_name, env in var.environments :
    env_name => <<-EOT
metric.type="${local.request_metric_type[env_name]}"
resource.type="k8s_container"
metric.label."destination_canonical_service"="${var.service_name}"
metric.label."namespace"="${env.namespace}"
EOT
  }

  # shared prefix for latency SLO filters (per env)
  latency_filter_prefix = {
    for env_name, env in var.environments :
    env_name => <<-EOT
metric.type="${local.latency_metric_type[env_name]}"
resource.type="k8s_container"
metric.label."destination_canonical_service"="${var.service_name}"
metric.label."namespace"="${env.namespace}"
EOT
  }

  # helper: OR clause for class list
  status_class_or = {
    for ep in var.endpoints :
    ep.name => (
      length(ep.good_status_classes) > 0 ?
      "(${join(" OR ", [for c in ep.good_status_classes : "metric.label.\"status_class\"=\"${c}\""])})"
      : ""
    )
  }

  status_class_total_or = {
    for ep in var.endpoints :
    ep.name => (
      length(ep.total_status_classes) > 0 ?
      "(${join(" OR ", [for c in ep.total_status_classes : "metric.label.\"status_class\"=\"${c}\""])})"
      : ""
    )
  }
  
  slo_config = {
    for env_name, env in var.environments :
    env_name => concat(
      # Availability SLOs for this env
      [
        for ep in var.endpoints : {
          service = "${env_name}-${var.service_name}-${var.cuj}"
          slo_id  = "istio_${env_name}_${ep.name}_${var.cuj}_availability"
          display_name = "Istio ${ep.name} ${env_name} Availability"

          goal               = ep.availability_goal
          rolling_period_days = ep.rolling_period_days

          type   = "request_based_sli"
          method = "good_total_ratio"

          good_service_filter = <<-EOT
${trimspace(local.availability_filter_prefix[env_name])}
${ep.method != "" ? "metric.label.\"http_method\"=\"${ep.method}\"" : ""}
${ep.path   != "" ? "metric.label.\"http_path\"=\"${ep.path}\""       : ""}
${local.status_class_or[ep.name]}
EOT

          bad_service_filter = <<-EOT
${trimspace(local.availability_filter_prefix[env_name])}
${ep.method != "" ? "metric.label.\"http_method\"=\"${ep.method}\"" : ""}
${ep.path   != "" ? "metric.label.\"http_path\"=\"${ep.path}\""       : ""}
${local.status_class_total_or[ep.name]}
EOT
        } if ep.availability_goal > 0
      ],

      # Latency SLOs for this env
      [
        for ep in var.endpoints : {
          service = "${env_name}-${var.service_name}-${var.cuj}"
          slo_id  = "istio_${env_name}_${ep.name}_${var.cuj}_latency"
          display_name = "Istio ${ep.name} ${env_name} Latency"

          goal               = ep.latency_goal
          rolling_period_days = ep.rolling_period_days

          type   = "request_based_sli"
          method = "distribution_cut"

          metric_filter = <<-EOT
${trimspace(local.latency_filter_prefix[env_name])}
${ep.method != "" ? "metric.label.\"http_method\"=\"${ep.method}\"" : ""}
${ep.path   != "" ? "metric.label.\"http_path\"=\"${ep.path}\""       : ""}
(metric.label."status_class"="2" OR metric.label."status_class"="3")
EOT

          # Add these only if your db-monitoring/google module expects them:
          threshold_seconds = ep.latency_threshold_ms / 1000
          percentile        = 95
        } if ep.latency_goal > 0 && ep.latency_threshold_ms > 0
      ]
    )
  }
}

module "service" {
  for_each   = var.environments
  source     = "tfe.gcp.db.com/PMR/db-monitoring/google"
  version    = "0.1.1"
  project_id = var.project_id
  environment = each.key

  log_metric_config = [
    {
      name        = "${each.key}_istio-requests-total_${var.service_name}"
      description = "Total HTTP requests for ${var.service_name} in ${each.key}"
      filter      = local.base_log_filter[each.key]

      label_extractors = local.label_extractors
      metric_descriptor = {
        metric_kind = "DELTA"
        value_type  = "INT64"
        unit        = "1"
        labels      = local.labels
      }
    },
    {
      name        = "${each.key}_istio-latency_${var.service_name}"
      description = "Latency of HTTP requests for ${var.service_name} in ${each.key}"

      filter          = local.base_log_filter[each.key]
      value_extractor = "EXTRACT_DURATION(httpRequest.latency)"

      label_extractors = local.label_extractors
      metric_descriptor = {
        metric_kind = "DELTA"
        value_type  = "DISTRIBUTION"
        unit        = "s"
        labels      = local.labels
      }

      bucket_options = {
        exponential_buckets = {
          scale              = 0.005
          growth_factor      = 2
          num_finite_buckets = 15
        }
      }
    },
  ]

  # we will define slo_config in a local and pass it here:
  slo_config = local.slo_config[each.key]

  alert_policies = []
}