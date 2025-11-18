# This template is rendered by Terraform's templatefile() function.
# Inputs:
#   - env_name      : environment id, e.g. "ft1"
#   - env_ns        : environment namespace, e.g. "x-ft1"
#   - env_cluster   : cluster name, e.g. "x-gke-ft1"
#   - cuj_workloads : map(cuj_id => { name, workloads })
#
# We build a big HCL map and jsonencode() it into the final dashboard_json.

${jsonencode({

  # Dashboard title – includes cluster and environment id
  displayName = "GKE Service Status - ${env_cluster} - ${env_name}"

  # Extra labels for searching/grouping dashboards
  labels = {
    env     = env_name
    cluster = env_cluster
    type    = "statuspage"
    ns      = env_ns
  }

  # Global filter pinned at the top of the dashboard.
  # - filterType = METRIC_LABEL means it filters on a metric label called "namespace".
  # - stringValue = env_ns sets the default value for this filter.
  dashboardFilters = [
    {
      labelKey         = "namespace"
      filterType       = "METRIC_LABEL"
      templateVariable = "namespace"
      stringValue      = env_ns
    }
  ]

  # We use a Mosaic layout: 12 logical columns, free placement with (xPos, yPos).
  #
  # Coordinates:
  #   - xPos: horizontal position (0..11), width: number of columns.
  #   - yPos: vertical position (arbitrary units), height: how many "rows" it spans.
  #
  # Our convention:
  #   - Each CUJ gets a "vertical band" of height ~30 units.
  #   - The CUJ header is at the top of that band (height = 2).
  #   - Each service tile is 8 units tall, stacked under the header.
  #
  mosaicLayout = {
    # 12 columns is standard; we make tiles 8 columns wide and center them.
    columns = 12

    tiles = flatten([
      # Iterate CUJs in the order of keys(cuj_workloads).
      # cuj_index is 0-based; we multiply it by 30 to give each CUJ its own vertical band.
      for cuj_index, cuj_id in keys(cuj_workloads) : [

        # -------------------------------------------------------------------
        # CUJ HEADER TILE
        # -------------------------------------------------------------------
        {
          # Start at left edge, full width across all 12 columns.
          xPos   = 0
          yPos   = cuj_index * 30  # each CUJ gets its own vertical band of size 30
          width  = 12
          height = 2               # small, only for the title / description

          widget = {
            # Title shows CUJ id + human name + environment
            title = "CUJ: ${cuj_id} - ${cuj_workloads[cuj_id].name} (${env_name})"

            text = {
              format = "MARKDOWN"

              # We display CUJ id, name, env, namespace, and cluster so SREs
              # immediately know what they are looking at.
              content = "### ${cuj_id} - ${cuj_workloads[cuj_id].name} (${env_name})\nNamespace: `${env_ns}`\nCluster: `${env_cluster}`\nStatus of workloads in this critical user journey."
            }
          }
        },

        # -------------------------------------------------------------------
        # SERVICE TILES (8x8) FOR THIS CUJ
        # -------------------------------------------------------------------
        # For each workload (service) in this CUJ we create one big tile.
        #
        # Layout decisions:
        #   - width  = 8  : tile spans 8 of the 12 columns
        #   - xPos   = 2  : centers the tile horizontally (columns 2..9)
        #   - height = 8  : tall tile -> easy to read on statusboard screen
        #   - yPos   = cuj_index * 30 + 2 (skip header) + svc_index * 8
        #              -> stacks tiles vertically within the CUJ band.
        #
        for svc_index, svc in cuj_workloads[cuj_id].workloads : {
          xPos   = 2
          yPos   = cuj_index * 30 + 2 + svc_index * 8
          width  = 8
          height = 8

          widget = {
            title = "Service: ${svc} (${cuj_id} ${cuj_workloads[cuj_id].name}, env: ${env_name})"

            scorecard = {
              # Time series query using Managed Service for Prometheus.
              #
              # The idea:
              #   - Use "up" metric for each workload/pod.
              #   - min_over_time(...) over 5 minutes:
              #       * 1 -> all targets up during the last 5m
              #       * 0 -> some target was down at least once in last 5m
              #
              # Labels assume:
              #   - job      = "kubernetes-pods"
              #   - cluster  = env_cluster
              #   - namespace= env_ns
              #   - workload = Kubernetes workload name (svc)
              #
              # Adjust label names or metric if your AMP schema differs.
              timeSeriesQuery = {
                prometheusQuery = "min_over_time(up{job=\"kubernetes-pods\", cluster=\"${env_cluster}\", namespace=\"${env_ns}\", workload=\"${svc}\"}[5m])"
              }

              # Gauge renders a single numeric value (0..1) as a dial.
              gaugeView = {
                lowerBound = 0
                upperBound = 1
              }

              # Threshold:
              #   - If value < 0.5 -> considered DOWN, gauge turns RED in UI.
              #   - For typical 'up' metric this means:
              #       1.0 -> healthy
              #       0.0 -> down/unhealthy
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
    ])
  }
})}