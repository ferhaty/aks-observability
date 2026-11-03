mock_provider "helm" {}
variables {
  environment        = { "tenant_id" : "22222222-2222-4222-8222-222222222222", "collector_client_id" : "11111111-1111-4111-8111-111111111111", "grafana_client_id" : "55555555-5555-4555-8555-555555555555", "trace_endpoint" : "https://generated.offline.ingest.monitor.azure.com/datacollectionRules/dcr-generated-offline/streams/Microsoft-OTLP-Traces/otlp/v1/traces", "prometheus_query_url" : "https://generated.offline.prometheus.monitor.azure.com" }
  kubeconfig_path    = "./absent"
  kubeconfig_context = "offline"
}
run "helm_contract" {
  command = apply

  assert {
    condition     = helm_release.collector.version == "0.176.1" && helm_release.grafana.version == "14.0.1"
    error_message = "Pinned chart versions required."
  }

  assert {
    condition     = output.collector_values.config.service.pipelines.metrics == null && output.collector_values.config.service.pipelines.logs == null
    error_message = "Collector must be traces-only."
  }

  assert {
    condition     = output.grafana_values.datasources["datasources.yaml"].datasources[0].jsonData.azureCredentials.authType == "workloadidentity"
    error_message = "Grafana must use Workload Identity."
  }
}
run "reject_http" {
  command = plan
  variables { environment = merge(var.environment, { trace_endpoint = "http://invalid/v1/traces" }) }
  expect_failures = [var.environment]
}
run "reject_shared_identity" {
  command = plan
  variables { environment = merge(var.environment, { grafana_client_id = var.environment.collector_client_id }) }
  expect_failures = [var.environment]
}
run "reject_connection_string" {
  command = plan
  variables { environment = merge(var.environment, { trace_endpoint = "InstrumentationKey=not-an-otlp-endpoint" }) }
  expect_failures = [var.environment]
}
