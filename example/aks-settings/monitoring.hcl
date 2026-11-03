# Merge INSIDE the same existing AKS resource after observability has been applied.
monitor_metrics {
  annotations_allowed = null
  labels_allowed      = null
}
oms_agent {
  log_analytics_workspace_id      = var.observability_log_analytics_workspace_id
  msi_auth_for_monitoring_enabled = true
}
