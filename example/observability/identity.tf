resource "azurerm_user_assigned_identity" "traces" {
  name                = "${var.name}-traces"
  resource_group_name = var.resource_group_name
  location            = data.azapi_resource.aks.location
}
resource "azurerm_federated_identity_credential" "traces" {
  name                      = "podinfo-collector"
  user_assigned_identity_id = azurerm_user_assigned_identity.traces.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = data.azapi_resource.aks.output.properties.oidcIssuerProfile.issuerURL
  subject                   = "system:serviceaccount:observability:otel-collector"
}
resource "azurerm_role_assignment" "trace_ingestion" {
  scope                = azapi_resource.trace_dcr.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.traces.principal_id
}
resource "azurerm_user_assigned_identity" "grafana" {
  name                = "${var.name}-grafana"
  resource_group_name = var.resource_group_name
  location            = data.azapi_resource.aks.location
}
resource "azurerm_federated_identity_credential" "grafana" {
  name                      = "${var.name}-grafana"
  user_assigned_identity_id = azurerm_user_assigned_identity.grafana.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = data.azapi_resource.aks.output.properties.oidcIssuerProfile.issuerURL
  subject                   = "system:serviceaccount:observability:grafana"
}
resource "azurerm_role_assignment" "grafana_metrics" {
  scope                = azurerm_monitor_workspace.metrics.id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_user_assigned_identity.grafana.principal_id
}
