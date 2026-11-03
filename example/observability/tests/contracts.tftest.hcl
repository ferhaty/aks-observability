override_data {
  target = data.azurerm_resource_group.monitoring
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks", "name" : "offline-aks", "location" : "westeurope" }
}
override_data {
  target = data.azapi_resource.aks
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.ContainerService/managedClusters/offline-aks", "location" : "westeurope", "output" : { "properties" : { "oidcIssuerProfile" : { "enabled" : true, "issuerURL" : "https://offline.oic.prod-aks.azure.com/tenant/cluster/" }, "securityProfile" : { "workloadIdentity" : { "enabled" : true } } } } }
}
mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "helm" {}
override_resource {
  target = azurerm_monitor_workspace.metrics
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.Monitor/accounts/offline-metrics", "query_endpoint" : "https://generated.offline.prometheus.monitor.azure.com" }
}
override_resource {
  target = azurerm_log_analytics_workspace.logs
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.OperationalInsights/workspaces/offline-logs" }
}
override_resource {
  target = azurerm_application_insights.traces
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.Insights/components/offline-traces" }
}
override_resource {
  target = azurerm_monitor_data_collection_endpoint.metrics
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.Insights/dataCollectionEndpoints/offline-prometheus" }
}
override_resource {
  target = azurerm_monitor_data_collection_rule.metrics
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.Insights/dataCollectionRules/offline-prometheus" }
}
override_resource {
  target = azurerm_monitor_data_collection_rule.logs
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.Insights/dataCollectionRules/offline-ci" }
}
override_resource {
  target = azurerm_user_assigned_identity.traces
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.ManagedIdentity/userAssignedIdentities/traces", "client_id" : "11111111-1111-4111-8111-111111111111", "principal_id" : "44444444-4444-4444-8444-444444444444" }
}
override_resource {
  target = azurerm_user_assigned_identity.grafana
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.ManagedIdentity/userAssignedIdentities/grafana", "client_id" : "55555555-5555-4555-8555-555555555555", "principal_id" : "66666666-6666-4666-8666-666666666666" }
}
override_resource {
  target = azapi_resource.trace_dce
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.Insights/dataCollectionEndpoints/offline-otlp", "output" : { "properties" : { "logsIngestion" : { "endpoint" : "https://generated.offline.ingest.monitor.azure.com" } } } }
}
override_resource {
  target = azapi_resource.trace_dcr
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.Insights/dataCollectionRules/offline-otlp", "output" : { "properties" : { "immutableId" : "dcr-generated-offline" } } }
}
variables {
  name                    = "offline-aks"
  aks_name                = "offline-aks"
  aks_resource_group_name = "offline-aks"
  kubeconfig_path         = "./absent"
  kubeconfig_context      = "offline"
  resource_group_name     = "offline-aks"
  subscription_id         = "00000000-0000-4000-8000-000000000000"
  tenant_id               = "22222222-2222-4222-8222-222222222222"
}
run "provisioned_graph" {
  command = apply

  assert {
    condition     = azurerm_application_insights.traces.workspace_id == azurerm_log_analytics_workspace.logs.id
    error_message = "AI must use our LAW."
  }

  assert {
    condition     = azapi_resource.trace_dcr.body.properties.references.applicationInsights[0].resourceId == azurerm_application_insights.traces.id
    error_message = "DCR must associate AI."
  }

  assert {
    condition     = azapi_resource.trace_dcr.body.properties.directDataSources.otelTraces[0].replaceResourceIdWithReference && azapi_resource.trace_dcr.body.properties.directDataSources.otelTraces[0].enrichWithReference == "applicationInsightsResource"
    error_message = "AI resource association must enrich and replace resource IDs."
  }

  assert {
    condition     = length(azapi_resource.trace_dcr.body.properties.directDataSources) == 1 && length(azapi_resource.trace_dcr.body.properties.dataFlows[0].streams) == 3
    error_message = "Only direct traces, all trace streams."
  }

  assert {
    condition     = yamldecode(helm_release.collector.values[0]).config.exporters["otlp_http/azure"].traces_endpoint == "https://generated.offline.ingest.monitor.azure.com/datacollectionRules/dcr-generated-offline/streams/Microsoft-OTLP-Traces/otlp/v1/traces"
    error_message = "Trace URL must derive from DCE response and immutable DCR ID, not resource ID."
  }

  assert {
    condition     = yamldecode(helm_release.grafana.values[0]).datasources["datasources.yaml"].datasources[0].url == azurerm_monitor_workspace.metrics.query_endpoint
    error_message = "Query URL must derive from AMW."
  }

  assert {
    condition     = azurerm_monitor_data_collection_rule_association.metrics.target_resource_id == data.azapi_resource.aks.id && azurerm_monitor_data_collection_rule_association.logs.target_resource_id == data.azapi_resource.aks.id
    error_message = "Both native rules must attach to existing AKS."
  }

  assert {
    condition     = azurerm_monitor_data_collection_rule.metrics.destinations[0].monitor_account[0].monitor_account_id == azurerm_monitor_workspace.metrics.id
    error_message = "Native metrics must reach our workspace."
  }

  assert {
    condition     = azurerm_monitor_data_collection_rule.logs.destinations[0].log_analytics[0].workspace_resource_id == azurerm_log_analytics_workspace.logs.id
    error_message = "Container logs must reach same LAW as traces."
  }

  assert {
    condition     = azurerm_role_assignment.trace_ingestion.scope == azapi_resource.trace_dcr.id && azurerm_role_assignment.trace_ingestion.role_definition_name == "Monitoring Metrics Publisher"
    error_message = "Trace grant must use new DCR."
  }

  assert {
    condition     = azurerm_role_assignment.grafana_metrics.scope == azurerm_monitor_workspace.metrics.id && azurerm_role_assignment.grafana_metrics.role_definition_name == "Monitoring Data Reader" && azurerm_role_assignment.grafana_metrics.principal_id != azurerm_role_assignment.trace_ingestion.principal_id
    error_message = "Separate Grafana read identity required."
  }

  assert {
    condition     = azurerm_federated_identity_credential.traces.issuer == data.azapi_resource.aks.output.properties.oidcIssuerProfile.issuerURL && azurerm_federated_identity_credential.grafana.subject == "system:serviceaccount:observability:grafana" && azurerm_federated_identity_credential.traces.subject == "system:serviceaccount:observability:otel-collector"
    error_message = "Exact issuer and separate service accounts required."
  }
  assert {
    condition = alltrue([
      toset(azapi_resource.trace_dcr.body.properties.directDataSources.otelTraces[0].streams) == toset(["Microsoft-OTel-Traces-Spans", "Microsoft-OTel-Traces-Events", "Microsoft-OTel-Traces-Resources"]),
      toset(azapi_resource.trace_dcr.body.properties.dataFlows[0].streams) == toset(azapi_resource.trace_dcr.body.properties.directDataSources.otelTraces[0].streams),
      azapi_resource.trace_dcr.body.properties.dataFlows[0].destinations[0] == azapi_resource.trace_dcr.body.properties.destinations.logAnalytics[0].name,
      azapi_resource.trace_dcr.body.properties.destinations.logAnalytics[0].workspaceResourceId == azurerm_log_analytics_workspace.logs.id,
      azapi_resource.trace_dcr.body.properties.dataCollectionEndpointId == azapi_resource.trace_dce.id,
      azapi_resource.trace_dcr.body.properties.references.applicationInsights[0].name == azapi_resource.trace_dcr.body.properties.directDataSources.otelTraces[0].enrichWithReference,
      toset(azapi_resource.trace_dcr.body.properties.directDataSources.otelTraces[0].enrichWithResourceAttributes) == toset(["*"])
    ])
    error_message = "Native OTLP source, flow, LAW, DCE and AI enrichment must be connected exactly."
  }
  assert {
    condition = alltrue([
      azurerm_monitor_data_collection_rule_association.metrics.data_collection_rule_id == azurerm_monitor_data_collection_rule.metrics.id,
      azurerm_monitor_data_collection_rule_association.logs.data_collection_rule_id == azurerm_monitor_data_collection_rule.logs.id,
      azurerm_monitor_data_collection_rule_association.logs.name == "ContainerInsightsExtension",
      toset(azurerm_monitor_data_collection_rule.metrics.data_sources[0].prometheus_forwarder[0].streams) == toset(["Microsoft-PrometheusMetrics"]),
      toset(azurerm_monitor_data_collection_rule.metrics.data_flow[0].streams) == toset(["Microsoft-PrometheusMetrics"]),
      azurerm_monitor_data_collection_rule.metrics.data_flow[0].destinations[0] == azurerm_monitor_data_collection_rule.metrics.destinations[0].monitor_account[0].name,
      azurerm_monitor_data_collection_rule.logs.data_sources[0].extension[0].extension_name == "ContainerInsights",
      toset(azurerm_monitor_data_collection_rule.logs.data_sources[0].extension[0].streams) == toset(["Microsoft-ContainerLogV2"]),
      jsondecode(azurerm_monitor_data_collection_rule.logs.data_sources[0].extension[0].extension_json).dataCollectionSettings.enableContainerLogV2,
      toset(azurerm_monitor_data_collection_rule.logs.data_flow[0].streams) == toset(["Microsoft-ContainerLogV2"]),
      azurerm_monitor_data_collection_rule.logs.data_flow[0].destinations[0] == azurerm_monitor_data_collection_rule.logs.destinations[0].log_analytics[0].name,
      azurerm_monitor_data_collection_rule.logs.data_flow[0].transform_kql == "source"
    ])
    error_message = "Native metrics and ContainerLogV2 must retain exact streams, destinations and AKS associations."
  }
  assert {
    condition = alltrue([
      azurerm_role_assignment.trace_ingestion.principal_id == azurerm_user_assigned_identity.traces.principal_id,
      azurerm_role_assignment.grafana_metrics.principal_id == azurerm_user_assigned_identity.grafana.principal_id,
      azurerm_federated_identity_credential.traces.user_assigned_identity_id == azurerm_user_assigned_identity.traces.id,
      azurerm_federated_identity_credential.grafana.user_assigned_identity_id == azurerm_user_assigned_identity.grafana.id,
      azurerm_federated_identity_credential.grafana.issuer == data.azapi_resource.aks.output.properties.oidcIssuerProfile.issuerURL,
      toset(azurerm_federated_identity_credential.traces.audience) == toset(["api://AzureADTokenExchange"]),
      toset(azurerm_federated_identity_credential.grafana.audience) == toset(["api://AzureADTokenExchange"])
    ])
    error_message = "Reader and writer roles/federations must bind their own identity and token audience."
  }


  assert {
    condition = alltrue([
      yamldecode(helm_release.collector.values[0]).serviceAccount.annotations["azure.workload.identity/client-id"] == azurerm_user_assigned_identity.traces.client_id,
      yamldecode(helm_release.grafana.values[0]).serviceAccount.annotations["azure.workload.identity/client-id"] == azurerm_user_assigned_identity.grafana.client_id,
      yamldecode(helm_release.collector.values[0]).serviceAccount.annotations["azure.workload.identity/tenant-id"] == var.tenant_id,
      yamldecode(helm_release.grafana.values[0]).serviceAccount.annotations["azure.workload.identity/tenant-id"] == var.tenant_id,
      yamldecode(helm_release.collector.values[0]).config.service.pipelines.metrics == null,
      yamldecode(helm_release.collector.values[0]).config.service.pipelines.logs == null,
      yamldecode(helm_release.grafana.values[0]).datasources["datasources.yaml"].datasources[0].jsonData.azureCredentials.authType == "workloadidentity",
      helm_release.collector.version == "0.176.1",
      helm_release.grafana.version == "14.0.1",
      output.log_analytics_workspace_id == azurerm_log_analytics_workspace.logs.id
    ])
    error_message = "Helm must consume direct resource outputs with separate workload identities."
  }
}
run "reject_oidc_disabled" {
  command = plan
  override_data {
    target = data.azapi_resource.aks
    values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.ContainerService/managedClusters/offline-aks", "location" : "westeurope", "output" : { "properties" : { "oidcIssuerProfile" : { "enabled" : false, "issuerURL" : "https://offline.oic.prod-aks.azure.com/tenant/cluster/" }, "securityProfile" : { "workloadIdentity" : { "enabled" : true } } } } }
  }
  expect_failures = [data.azapi_resource.aks]
}
run "reject_http_issuer" {
  command = plan
  override_data {
    target = data.azapi_resource.aks
    values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.ContainerService/managedClusters/offline-aks", "location" : "westeurope", "output" : { "properties" : { "oidcIssuerProfile" : { "enabled" : true, "issuerURL" : "http://invalid/" }, "securityProfile" : { "workloadIdentity" : { "enabled" : true } } } } }
  }
  expect_failures = [data.azapi_resource.aks]
}
run "reject_workload_identity_disabled" {
  command = plan
  override_data {
    target = data.azapi_resource.aks
    values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.ContainerService/managedClusters/offline-aks", "location" : "westeurope", "output" : { "properties" : { "oidcIssuerProfile" : { "enabled" : true, "issuerURL" : "https://offline.oic.prod-aks.azure.com/tenant/cluster/" }, "securityProfile" : { "workloadIdentity" : { "enabled" : false } } } } }
  }
  expect_failures = [data.azapi_resource.aks]
}
