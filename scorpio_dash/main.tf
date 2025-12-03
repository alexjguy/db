locals {
  # Your log-based metric type
  metric_type = "logging.googleapis.com/user/${var.env_name}_istio-requests-total_${var.service_name}"

  # Common filter pieces shared by all widgets
  common_filter_parts = [
    "metric.type=\"${local.metric_type}\"",
    "resource.type=\"k8s_container\"",
    "resource.labels.namespace_name=\"${var.namespace}\"",
    "metric.label.destination_canonical_service=\"${var.service_name}\"",
  ]

  # Build one widget per endpoint
  widgets = [
    for ep in var.endpoints : {
      title = "${ep.method} ${ep.name} - total vs 2xx vs other"

      xyChart = {
        dataSets = [

          #########################################
          # Total requests
          #########################################
          {
            legendTemplate = "Total"
            plotType       = "LINE"

            timeSeriesFilter = {
              filter = join(" AND ", concat(
                local.common_filter_parts,
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

          #########################################
          # 2xx (good)
          #########################################
          {
            legendTemplate = "2xx"
            plotType       = "LINE"

            timeSeriesFilter = {
              filter = join(" AND ", concat(
                local.common_filter_parts,
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

          #########################################
          # non-2xx (other)
          #########################################
          {
            legendTemplate = "non-2xx"
            plotType       = "LINE"

            timeSeriesFilter = {
              filter = join(" AND ", concat(
                local.common_filter_parts,
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

resource "google_monitoring_dashboard" "scorpio_compliance" {
  project = var.project_id

  dashboard_json = jsonencode({
    displayName = "Scorpio compliance - ${var.service_name} - ${var.env_name}"

    gridLayout = {
      columns = 2
      widgets = local.widgets
    }
  })
}