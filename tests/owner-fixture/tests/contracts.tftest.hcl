mock_provider "azurerm" {}
mock_provider "azapi" {}
mock_provider "helm" {}
# Root Helm config is intentionally not inherited by this legacy provider-config
# module. Override BOTH releases explicitly: never invoke Kubernetes in this test.
override_resource {
  target = module.tooling.helm_release.collector
  values = {}
}
override_resource {
  target = module.tooling.helm_release.grafana
  values = {}
}
override_resource {
  target = module.monitoring.azurerm_monitor_workspace.metrics
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.Monitor/accounts/offline-metrics", "query_endpoint" : "https://generated.offline.prometheus.monitor.azure.com" }
}
override_resource {
  target = module.monitoring.azurerm_log_analytics_workspace.logs
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.OperationalInsights/workspaces/offline-logs" }
}
override_resource {
  target = module.monitoring.azurerm_application_insights.traces
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.Insights/components/offline-traces" }
}
override_resource {
  target = module.monitoring.azurerm_monitor_data_collection_endpoint.metrics
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.Insights/dataCollectionEndpoints/offline-prometheus" }
}
override_resource {
  target = module.monitoring.azurerm_monitor_data_collection_rule.metrics
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.Insights/dataCollectionRules/offline-prometheus" }
}
override_resource {
  target = module.monitoring.azurerm_monitor_data_collection_rule.logs
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.Insights/dataCollectionRules/offline-ci" }
}
override_resource {
  target = module.monitoring.azurerm_user_assigned_identity.traces
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.ManagedIdentity/userAssignedIdentities/traces", "client_id" : "11111111-1111-4111-8111-111111111111", "principal_id" : "44444444-4444-4444-8444-444444444444" }
}
override_resource {
  target = module.monitoring.azurerm_user_assigned_identity.grafana
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.ManagedIdentity/userAssignedIdentities/grafana", "client_id" : "55555555-5555-4555-8555-555555555555", "principal_id" : "66666666-6666-4666-8666-666666666666" }
}
override_resource {
  target = module.monitoring.azapi_resource.trace_dce
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.Insights/dataCollectionEndpoints/offline-otlp", "output" : { "properties" : { "logsIngestion" : { "endpoint" : "https://generated.offline.ingest.monitor.azure.com" } } } }
}
override_resource {
  target = module.monitoring.azapi_resource.trace_dcr
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.Insights/dataCollectionRules/offline-otlp", "output" : { "properties" : { "immutableId" : "dcr-generated-offline" } } }
}
override_resource {
  target = azurerm_resource_group.aks
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks" }
}
override_resource {
  target = azurerm_kubernetes_cluster.aks
  values = { "id" : "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-aks/providers/Microsoft.ContainerService/managedClusters/offline-aks", "oidc_issuer_url" : "https://offline.oic.prod-aks.azure.com/tenant/cluster/" }
}
run "owner_to_pod_configuration" {
  command = apply

  assert {
    condition     = azurerm_kubernetes_cluster.aks.oms_agent[0].log_analytics_workspace_id == module.monitoring.log_analytics_workspace_id && azurerm_kubernetes_cluster.aks.oms_agent[0].msi_auth_for_monitoring_enabled
    error_message = "Existing AKS must use generated LAW with MSI."
  }

  assert {
    condition     = azurerm_kubernetes_cluster.aks.oidc_issuer_enabled && azurerm_kubernetes_cluster.aks.workload_identity_enabled && length(azurerm_kubernetes_cluster.aks.monitor_metrics) == 1
    error_message = "Owner must enable native metrics and Workload ID."
  }

  assert {
    condition     = module.tooling.collector_values.config.exporters["otlp_http/azure"].traces_endpoint == module.monitoring.workload_inputs.trace_endpoint
    error_message = "Collector endpoint must propagate from resource outputs."
  }

  assert {
    condition     = module.tooling.collector_values.serviceAccount.annotations["azure.workload.identity/client-id"] == module.monitoring.workload_inputs.collector_client_id
    error_message = "Collector identity must propagate from outputs."
  }

  assert {
    condition     = module.tooling.grafana_values.datasources["datasources.yaml"].datasources[0].url == module.monitoring.workload_inputs.prometheus_query_url && module.tooling.grafana_values.serviceAccount.annotations["azure.workload.identity/client-id"] == module.monitoring.workload_inputs.grafana_client_id
    error_message = "Grafana must receive its own identity and generated query URL."
  }
}
