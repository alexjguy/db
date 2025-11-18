locals {
  # deterministic order of CUJs
  cuj_ids = sort(keys(var.cuj_workloads))

  # height of each CUJ block: header(2) + 8 per service tile
  cuj_height = {
    for id in local.cuj_ids :
    id => 2 + length(var.cuj_workloads[id].workloads) * 8
  }

  # vertical offset per CUJ so they don't overlap
  cuj_offset = {
    for idx, id in local.cuj_ids :
    id => (
      idx == 0 ?
      0 :
      sum([
        for j in range(idx) :
        local.cuj_height[local.cuj_ids[j]]
      ])
    )
  }

  # all tiles per environment (CUJ header + its services)
  env_tiles = {
    for env_name, env in var.x_environments :
    env_name => flatten([
      for cuj_id in local.cuj_ids : concat(
        # ---- CUJ header tile ----
        [
          {
            xPos   = 0
            yPos   = local.cuj_offset[cuj_id]
            width  = 12
            height = 2
            widget = {
              title = "CUJ: ${cuj_id} - ${var.cuj_workloads[cuj_id].name} (${env_name})"
              text = {
                format  = "MARKDOWN"
                content = "### ${cuj_id} - ${var.cuj_workloads[cuj_id].name} (${env_name})\nNamespace: `${env.namespace}`\nCluster: `${env.cluster}`"
              }
            }
          }
        ],

        # ---- service tiles for this CUJ ----
        [
          for svc_index, svc in var.cuj_workloads[cuj_id].workloads : {
            xPos   = 2
            yPos   = local.cuj_offset[cuj_id] + 2 + svc_index * 8
            width  = 8
            height = 8
            widget = {
              title = "Service: ${svc} (${cuj_id} ${var.cuj_workloads[cuj_id].name}, env: ${env_name})"
              scorecard = {
                timeSeriesQuery = {
                  prometheusQuery = "min_over_time(up{job=\"kubernetes-pods\", cluster=\"${env.cluster}\", namespace=\"${env.namespace}\", workload=\"${svc}\"}[5m])"
                }
                gaugeView = {
                  lowerBound = 0
                  upperBound = 1
                }
                thresholds = [
                  {
                    label     = "Down"
                    value     = 0.5
                    color     = "RED"
                    direction = "BELOW"
                  }
                ]
              }
            }
          }
        ]
      )
    ])
  }
}

resource "google_monitoring_dashboard" "gke_service_status" {
  for_each = var.x_environments

  project = var.project_id

dashboard_json = jsonencode({
    displayName = "GKE Service Status - ${each.value.cluster} - ${each.key}"

    labels = {
      env     = each.key
      cluster = each.value.cluster
      type    = "statuspage"
      ns      = each.value.namespace
    }

    dashboardFilters = [
      {
        labelKey         = "namespace"
        filterType       = "METRIC_LABEL"
        templateVariable = "namespace"
        stringValue      = each.value.namespace
      }
    ]

    mosaicLayout = {
      columns = 12
      tiles   = local.env_tiles[each.key]
    }
  })
}