resource "azurerm_monitor_workspace" "metrics" {
  name                          = "${var.name}-metrics"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  public_network_access_enabled = true
}
resource "azurerm_log_analytics_workspace" "logs" {
  name                = "${var.name}-logs"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
# Manual OTLP orchestration: ordinary workspace-based AI; do not enable
# automatic OTLP workspace creation in the portal as a second onboarding path.
resource "azurerm_application_insights" "traces" {
  name                         = "${var.name}-traces"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  workspace_id                 = azurerm_log_analytics_workspace.logs.id
  application_type             = "other"
  retention_in_days            = 30
  local_authentication_enabled = false
}
