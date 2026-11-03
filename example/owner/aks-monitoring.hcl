# Merge these properties INSIDE the existing azurerm_kubernetes_cluster.aks.
# Preserve all other cluster properties and its Terraform resource address.
monitor_metrics {
  annotations_allowed = null
  labels_allowed      = null
}
oms_agent {
  log_analytics_workspace_id      = module.monitoring.log_analytics_workspace_id
  msi_auth_for_monitoring_enabled = true
}
oidc_issuer_enabled       = true
workload_identity_enabled = true
