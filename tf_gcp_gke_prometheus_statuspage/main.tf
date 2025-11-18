module "gke_statuspage" {
  source = "./modules/gke-statuspage"

  project_id = "my-project"
  cluster    = "x-gke-prod"

  x_environments = {
    ft1 = {
      namespace      = "x-ft1"
      alerts_enabled = false
    }
    sit1 = {
      namespace      = "x-sit1"
      alerts_enabled = false
    }
  }

  cuj_workloads = {
    "checkout-flow" = ["frontend", "checkout-api", "payments-api"]
    "user-profile"  = ["user-api", "notifications-api"]
  }
}