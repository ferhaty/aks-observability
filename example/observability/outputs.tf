# This is the only value passed back to the existing AKS configuration.
output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.logs.id
}
output "inspection" {
  value = {
    aks_id                     = data.azapi_resource.aks.id
    application_insights_id    = azurerm_application_insights.traces.id
    log_analytics_workspace_id = azurerm_log_analytics_workspace.logs.id
    monitor_workspace_id       = azurerm_monitor_workspace.metrics.id
    trace_dcr_id               = azapi_resource.trace_dcr.id
    trace_endpoint             = local.trace_endpoint
    metrics_dcr_id             = azurerm_monitor_data_collection_rule.metrics.id
    logs_dcr_id                = azurerm_monitor_data_collection_rule.logs.id
  }
}
