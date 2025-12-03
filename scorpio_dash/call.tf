module "scorpio_compliance_dashboard" {
  source = "./modules/istio-compliance-dashboard"

  project_id           = var.project_id
  service_name         = "scorpio-cm-request-proxy"
  environments         = var.x_environments
  request_metric_suffix = "istio-availability" # or "istio-requests-total" if you rename

  endpoints = [
    {
      name       = "/integration/scorpio"
      method     = "POST"
      path       = "/integration/scorpio"
      path_regex = ""
    },
    {
      name       = "/integration/scorpio"
      method     = "PUT"
      path       = "/integration/scorpio"
      path_regex = ""
    },
    {
      name       = "/integration/scorpio/{dealId}"
      method     = "GET"
      path       = ""
      path_regex = "^/integration/scorpio/[^/]+$"
    },
    {
      name       = "/integration/scorpio/confirmation"
      method     = "POST"
      path       = "/integration/scorpio/confirmation"
      path_regex = ""
    },
    {
      name       = "OPTIONS /integration/scorpio*"
      method     = "OPTIONS"
      path       = ""
      path_regex = "^/integration/scorpio(/confirmation|/[^/]+)?$"
    },
  ]
}