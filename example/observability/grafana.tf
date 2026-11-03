resource "helm_release" "grafana" {
  name             = "grafana"
  namespace        = "observability"
  create_namespace = false
  repository       = "https://grafana-community.github.io/helm-charts"
  chart            = "grafana"
  version          = "14.0.1"
  values = [templatefile("${path.module}/grafana.yaml.tftpl", {
    client_id         = azurerm_user_assigned_identity.grafana.client_id
    tenant_id         = var.tenant_id
    query_url         = azurerm_monitor_workspace.metrics.query_endpoint
    admin_secret_name = var.grafana_admin_secret_name
  })]
  depends_on = [
    azurerm_federated_identity_credential.grafana,
    azurerm_role_assignment.grafana_metrics
  ]
  wait    = true
  timeout = 600
}
