locals {
  # Only build dashboards for envs that are "enabled"
  active_environments = {
    for env_name, env in var.environments :
    env_name => env
    if env.alerts_enabled
  }

  # Common filter pieces per env
  env_common_filters = {
    for env_name, env in local.active_environments :
    env_name => [
      "metric.type=\"logging.googleapis.com/user/${env_name}_istio-requests-total_${var.service_name}\"",
      "resource.type=\"k8s_container\"",
      "resource.labels.namespace_name=\"${env.namespace}\"",
      "metric.label.destination_canonical_service=\"${var.service_name}\"",
    ]
  }

  # Widgets per env (one widget per endpoint, 3 series per widget)
  env_widgets = {
    for env_name, env in local.active_environments :
    env_name => [
      for ep in var.endpoints : {
        title = "${env_name} - ${ep.method} ${ep.name} - total vs 2xx vs other"

        xyChart = {
          dataSets = [

            # Total
            {
              legendTemplate = "Total"
              plotType       = "LINE"

              timeSeriesFilter = {
                filter = join(" AND ", concat(
                  local.env_common_filters[env_name],
                  [
                    "metric.label.http_method=\"${ep.method}\"",
                    ep.path_regex != "" ?
                      "metric.label.http_path=~\"${ep.path_regex}\"" :
                      "metric.label.http_path=\"${ep.path}\"",
                  ]
                ))

                aggregation = {
                  alignmentPeriod  = var.alignment_period
                  perSeriesAligner = "ALIGN_DELTA"
                }
              }
            },

            # 2xx
            {
              legendTemplate = "2xx"
              plotType       = "LINE"

              timeSeriesFilter = {
                filter = join(" AND ", concat(
                  local.env_common_filters[env_name],
                  [
                    "metric.label.http_method=\"${ep.method}\"",
                    ep.path_regex != "" ?
                      "metric.label.http_path=~\"${ep.path_regex}\"" :
                      "metric.label.http_path=\"${ep.path}\"",
                    "metric.label.status_class=\"2\"",
                  ]
                ))

                aggregation = {
                  alignmentPeriod  = var.alignment_period
                  perSeriesAligner = "ALIGN_DELTA"
                }
              }
            },

            # non-2xx
            {
              legendTemplate = "non-2xx"
              plotType       = "LINE"

              timeSeriesFilter = {
                filter = join(" AND ", concat(
                  local.env_common_filters[env_name],
                  [
                    "metric.label.http_method=\"${ep.method}\"",
                    ep.path_regex != "" ?
                      "metric.label.http_path=~\"${ep.path_regex}\"" :
                      "metric.label.http_path=\"${ep.path}\"",
                    "metric.label.status_class!=\"2\"",
                  ]
                ))

                aggregation = {
                  alignmentPeriod  = var.alignment_period
                  perSeriesAligner = "ALIGN_DELTA"
                }
              }
            },
          ]

          yAxis = {
            label = "Requests per ${var.alignment_period}"
            scale = "LINEAR"
          }
        }
      }
    ]
  }
}

resource "google_monitoring_dashboard" "scorpio_compliance" {
  for_each = local.active_environments

  project = var.project_id

  dashboard_json = jsonencode({
    displayName = "Scorpio compliance - ${var.service_name} - ${each.key}"

    gridLayout = {
      columns = 2
      widgets = local.env_widgets[each.key]
    }
  })
}