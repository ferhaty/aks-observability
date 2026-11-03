mock_provider "azurerm" {}
mock_provider "helm" {}
variables {
  environment = {
    subscription_id      = "00000000-0000-4000-8000-000000000000"
    tenant_id            = "22222222-2222-4222-8222-222222222222"
    resource_group_name  = "offline-observability"
    location             = "westeurope"
    oidc_issuer_url      = "https://offline.oic.prod-aks.azure.com/tenant/cluster/"
    trace_dcr_id         = "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline/providers/Microsoft.Insights/dataCollectionRules/traces"
    trace_endpoint       = "https://offline.westeurope-1.ingest.monitor.azure.com/datacollectionRules/dcr-offline/streams/Microsoft-OTLP-Traces/otlp/v1/traces"
    monitor_workspace_id = "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline/providers/Microsoft.Monitor/accounts/metrics"
    prometheus_query_url = "https://offline.westeurope.prometheus.monitor.azure.com"
    kubeconfig_path      = "./nonexistent-offline-kubeconfig"
    kubeconfig_context   = "offline"
  }
}
override_resource {
  target = azurerm_user_assigned_identity.traces
  values = {
    id           = "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-observability/providers/Microsoft.ManagedIdentity/userAssignedIdentities/podinfo-traces"
    client_id    = "11111111-1111-4111-8111-111111111111"
    principal_id = "44444444-4444-4444-8444-444444444444"
  }
}
override_resource {
  target = azurerm_user_assigned_identity.grafana
  values = {
    id           = "/subscriptions/00000000-0000-4000-8000-000000000000/resourceGroups/offline-observability/providers/Microsoft.ManagedIdentity/userAssignedIdentities/podinfo-grafana"
    client_id    = "55555555-5555-4555-8555-555555555555"
    principal_id = "66666666-6666-4666-8666-666666666666"
  }
}
run "identity_and_pipeline" {
  command = apply
  assert {
    condition     = azurerm_federated_identity_credential.grafana.subject == "system:serviceaccount:observability:grafana" && azurerm_federated_identity_credential.grafana.issuer == var.environment.oidc_issuer_url && azurerm_federated_identity_credential.grafana.audience == tolist(["api://AzureADTokenExchange"])
    error_message = "Grafana federation must match the dedicated SA, issuer and exchange audience."
  }
  assert {
    condition     = azurerm_role_assignment.grafana_metrics.role_definition_name == "Monitoring Data Reader" && azurerm_user_assigned_identity.grafana.client_id != azurerm_user_assigned_identity.traces.client_id && azurerm_role_assignment.grafana_metrics.principal_id != azurerm_role_assignment.trace_ingestion.principal_id
    error_message = "Separate Grafana read and Collector write identities required."
  }
  assert {
    condition     = helm_release.grafana.version == "14.0.1" && helm_release.grafana.namespace == "observability" && yamldecode(helm_release.grafana.values[0]).serviceAccount.annotations["azure.workload.identity/client-id"] == azurerm_user_assigned_identity.grafana.client_id && yamldecode(helm_release.grafana.values[0]).datasources["datasources.yaml"].datasources[0].url == var.environment.prometheus_query_url
    error_message = "Pinned Grafana chart must receive its client ID and query endpoint."
  }
  assert {
    condition     = azurerm_federated_identity_credential.traces.subject == "system:serviceaccount:observability:otel-collector"
    error_message = "Federation must bind the exact Collector service account."
  }
  assert {
    condition     = azurerm_role_assignment.trace_ingestion.scope == var.environment.trace_dcr_id && azurerm_role_assignment.trace_ingestion.role_definition_name == "Monitoring Metrics Publisher"
    error_message = "Trace ingest permission must be DCR-scoped."
  }
  assert {
    condition     = azurerm_role_assignment.grafana_metrics.scope == var.environment.monitor_workspace_id && azurerm_role_assignment.grafana_metrics.principal_id == azurerm_user_assigned_identity.grafana.principal_id
    error_message = "Grafana must use its own identity at the metrics workspace."
  }
  assert {
    condition     = helm_release.collector.version == "0.176.1" && helm_release.collector.namespace == "observability"
    error_message = "Pinned Collector chart and namespace required."
  }
}
run "reject_non_tls_query_endpoint" {
  command = plan
  variables {
    environment = merge(var.environment, { prometheus_query_url = "http://localhost:9090" })
  }
  expect_failures = [var.environment]
}
run "reject_non_tls_trace_endpoint" {
  command = plan
  variables {
    environment = merge(var.environment, { trace_endpoint = "http://localhost:4318/v1/traces" })
  }
  expect_failures = [var.environment]
}
