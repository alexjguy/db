module "project-x_cuj1_istio_log_slo" {
  source = "./project-x/modules/istio-log-based-slo"

  project_id            = var.project_id
  environments          = var.x_environments
  notification_channels = var.notification_channels

  cuj          = "cuj1"
  service_name = "x-deal-api-gateway"

  endpoints = [
    {
      name   = "login"
      method = "POST"
      path   = "/api/v1/login"

      good_status_classes  = ["2"]
      total_status_classes = ["2","3","4","5"]

      availability_goal    = var.x_availability_goal
      rolling_period_days  = 28

      latency_goal         = 0.99
      latency_threshold_ms = 300
    },
    {
      name   = "get-profile"
      method = "GET"
      path   = "/api/v1/profile"

      good_status_classes  = ["2","3"]
      total_status_classes = ["2","3","4","5"]

      availability_goal    = 0.995
      rolling_period_days  = 30

      latency_goal         = 0.99
      latency_threshold_ms = 500
    }
  ]
}