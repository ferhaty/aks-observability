# Narrowed from Microsoft's OTLP_DCE_DCR_ARM_Template.txt:
# direct Collector traces only; keep all three trace streams and AI enrichment.
# These native OTLP fields are absent from AzureRM 5.12.0; use the documented ARM API.
# Keep AzAPI schema validation enabled; no live ARM preflight is part of local tests.
resource "azapi_resource" "trace_dce" {
  type      = "Microsoft.Insights/dataCollectionEndpoints@2024-03-11"
  name      = "${var.name}-otlp"
  parent_id = var.resource_group_id
  location  = var.location
  body = {
    properties = {
      description = "Direct OTLP trace ingestion"
      networkAcls = { publicNetworkAccess = "Enabled" }
    }
  }
  response_export_values = ["properties.logsIngestion.endpoint"]
}
locals {
  trace_streams = [
    "Microsoft-OTel-Traces-Spans",
    "Microsoft-OTel-Traces-Events",
    "Microsoft-OTel-Traces-Resources"
  ]
}
resource "azapi_resource" "trace_dcr" {
  type                      = "Microsoft.Insights/dataCollectionRules@2024-03-11"
  name                      = "${var.name}-otlp"
  parent_id                 = var.resource_group_id
  location                  = var.location
  schema_validation_enabled = true
  body = {
    properties = {
      description              = "Direct OTLP traces with Application Insights association"
      dataCollectionEndpointId = azapi_resource.trace_dce.id
      references = {
        applicationInsights = [{
          resourceId = azurerm_application_insights.traces.id
          name       = "applicationInsightsResource"
        }]
      }
      directDataSources = {
        otelTraces = [{
          streams                        = local.trace_streams
          enrichWithResourceAttributes   = ["*"]
          enrichWithReference            = "applicationInsightsResource"
          replaceResourceIdWithReference = true
          name                           = "otelTracesDataSourceDirect"
        }]
      }
      destinations = {
        logAnalytics = [{
          workspaceResourceId = azurerm_log_analytics_workspace.logs.id
          name                = "myLAW"
        }]
      }
      dataFlows = [{ streams = local.trace_streams, destinations = ["myLAW"] }]
    }
  }
  response_export_values = ["properties.immutableId"]
}
locals {
  trace_endpoint = "${trimsuffix(azapi_resource.trace_dce.output.properties.logsIngestion.endpoint, "/")}/datacollectionRules/${azapi_resource.trace_dcr.output.properties.immutableId}/streams/Microsoft-OTLP-Traces/otlp/v1/traces"
}
