resource "azurerm_monitor_data_collection_endpoint" "metrics" {
  name                          = "${var.name}-prometheus"
  resource_group_name           = var.resource_group_name
  location                      = data.azapi_resource.aks.location
  kind                          = "Linux"
  public_network_access_enabled = true
}
resource "azurerm_monitor_data_collection_rule" "metrics" {
  name                        = "${var.name}-prometheus"
  resource_group_name         = var.resource_group_name
  location                    = data.azapi_resource.aks.location
  kind                        = "Linux"
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.metrics.id
  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.metrics.id
      name               = "MonitoringAccount1"
    }
  }
  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount1"]
  }
  data_sources {
    prometheus_forwarder {
      streams = ["Microsoft-PrometheusMetrics"]
      name    = "PrometheusDataSource"
    }
  }
}
resource "azurerm_monitor_data_collection_rule_association" "metrics" {
  name                    = "${var.name}-prometheus"
  target_resource_id      = data.azapi_resource.aks.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.metrics.id
}
resource "azurerm_monitor_data_collection_rule" "logs" {
  name                = "${var.name}-container-insights"
  resource_group_name = var.resource_group_name
  location            = data.azapi_resource.aks.location
  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.logs.id
      name                  = "ciworkspace"
    }
  }
  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      extension_name = "ContainerInsights"
      streams        = ["Microsoft-ContainerLogV2"]
      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = "1m"
          namespaceFilteringMode = "Off"
          namespaces             = []
          enableContainerLogV2   = true
        }
      })
    }
  }
  data_flow {
    streams       = ["Microsoft-ContainerLogV2"]
    destinations  = ["ciworkspace"]
    transform_kql = "source"
  }
}
resource "azurerm_monitor_data_collection_rule_association" "logs" {
  name                    = "ContainerInsightsExtension"
  target_resource_id      = data.azapi_resource.aks.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.logs.id
}
