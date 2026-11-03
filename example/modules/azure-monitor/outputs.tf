# This output depends ONLY on LAW; AKS can consume it without a module-wide cycle.
output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.logs.id
}
output "workload_inputs" {
  value = {
    tenant_id            = var.tenant_id
    collector_client_id  = azurerm_user_assigned_identity.traces.client_id
    grafana_client_id    = azurerm_user_assigned_identity.grafana.client_id
    trace_endpoint       = local.trace_endpoint
    prometheus_query_url = azurerm_monitor_workspace.metrics.query_endpoint
  }
  depends_on = [
    azurerm_federated_identity_credential.traces,
    azurerm_federated_identity_credential.grafana,
    azurerm_role_assignment.trace_ingestion,
    azurerm_role_assignment.grafana_metrics,
    azurerm_monitor_data_collection_rule_association.metrics,
    azurerm_monitor_data_collection_rule_association.logs
  ]
}
output "inspection" {
  value = {
    aks_id                     = var.aks_id
    application_insights_id    = azurerm_application_insights.traces.id
    log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
    monitor_workspace_id       = azurerm_monitor_workspace.metrics.id
    trace_dcr_id               = azapi_resource.trace_dcr.id
    trace_endpoint             = local.trace_endpoint
    metrics_dcr_id             = azurerm_monitor_data_collection_rule.metrics.id
    logs_dcr_id                = azurerm_monitor_data_collection_rule.logs.id
  }
}
