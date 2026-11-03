resource "helm_release" "collector" {
  name             = "otel-collector"
  namespace        = "observability"
  create_namespace = false
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-collector"
  version          = "0.176.1"
  values = [templatefile("${path.module}/collector.yaml.tftpl", {
    client_id      = var.environment.collector_client_id
    tenant_id      = var.environment.tenant_id
    trace_endpoint = var.environment.trace_endpoint
  })]
  wait    = true
  timeout = 600
}
