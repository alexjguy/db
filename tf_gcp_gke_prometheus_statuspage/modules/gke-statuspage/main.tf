resource "google_monitoring_dashboard" "gke_service_status" {
  for_each = var.x_environments

  project = var.project_id

  dashboard_json = templatefile(
    "${path.module}/gke_status_dashboard.tftpl",
    {
      env_name      = each.key
      env_ns        = each.value.namespace
      env_cluster   = each.value.cluster
      cuj_workloads = var.cuj_workloads
    }
  )
}