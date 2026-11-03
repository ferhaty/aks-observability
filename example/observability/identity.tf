resource "azurerm_user_assigned_identity" "traces" {
  name                = "podinfo-traces"
  resource_group_name = var.environment.resource_group_name
  location            = var.environment.location
}
resource "azurerm_federated_identity_credential" "traces" {
  name                      = "podinfo-collector"
  user_assigned_identity_id = azurerm_user_assigned_identity.traces.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.environment.oidc_issuer_url
  subject                   = "system:serviceaccount:observability:otel-collector"
}
resource "azurerm_role_assignment" "trace_ingestion" {
  scope                = var.environment.trace_dcr_id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.traces.principal_id
}
resource "azurerm_user_assigned_identity" "grafana" {
  name                = "podinfo-grafana"
  resource_group_name = var.environment.resource_group_name
  location            = var.environment.location
}
resource "azurerm_federated_identity_credential" "grafana" {
  name                      = "podinfo-grafana"
  user_assigned_identity_id = azurerm_user_assigned_identity.grafana.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.environment.oidc_issuer_url
  subject                   = "system:serviceaccount:observability:grafana"
}
resource "azurerm_role_assignment" "grafana_metrics" {
  scope                = var.environment.monitor_workspace_id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_user_assigned_identity.grafana.principal_id
}
output "collector_client_id" {
  value = azurerm_user_assigned_identity.traces.client_id
}
