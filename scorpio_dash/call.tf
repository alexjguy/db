module "scorpio_compliance_dashboard" {
  source = "./modules/istio-compliance-dashboard"

  project_id   = var.project_id
  env_name     = "siti"                    # or ft1 / sit1 / uat / ...
  namespace    = "x-sit1"
  service_name = "scorpio-cm-request-proxy"

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