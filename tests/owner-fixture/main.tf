terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "5.12.0" }
    azapi   = { source = "Azure/azapi", version = "2.13.0" }
    helm    = { source = "hashicorp/helm", version = "3.3.0" }
  }
}
provider "azurerm" {
  features {}
  subscription_id                 = "00000000-0000-4000-8000-000000000000"
  resource_provider_registrations = "none"
}
provider "azapi" {
  subscription_id            = "00000000-0000-4000-8000-000000000000"
  enable_preflight           = false
  skip_provider_registration = true
}
# MOCK-ONLY illustrative stand-in for an already-owned AKS resource.
# Do not apply/import this fixture; copy the integration, not the cluster.
resource "azurerm_resource_group" "aks" {
  name     = "offline-aks"
  location = "westeurope"
}
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "offline-aks"
  location            = "westeurope"
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = "offline-aks"
  default_node_pool {
    name       = "system"
    vm_size    = "Standard_D2s_v5"
    node_count = 1
  }
  node_provisioning_profile { mode = "Manual" }
  identity { type = "SystemAssigned" }
  monitor_metrics {
    annotations_allowed = null
    labels_allowed      = null
  }
  oms_agent {
    log_analytics_workspace_id      = module.monitoring.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  lifecycle { prevent_destroy = true }
}
module "monitoring" {
  source              = "../../example/modules/azure-monitor"
  name                = "offline-aks"
  resource_group_name = azurerm_resource_group.aks.name
  resource_group_id   = azurerm_resource_group.aks.id
  location            = "westeurope"
  subscription_id     = "00000000-0000-4000-8000-000000000000"
  tenant_id           = "22222222-2222-4222-8222-222222222222"
  aks_id              = azurerm_kubernetes_cluster.aks.id
  oidc_issuer_url     = azurerm_kubernetes_cluster.aks.oidc_issuer_url
}
module "tooling" {
  source             = "../../example/observability"
  environment        = module.monitoring.workload_inputs
  kubeconfig_path    = "./does-not-exist"
  kubeconfig_context = "offline-only"
}
output "observability_inputs" {
  value = { environment = module.monitoring.workload_inputs }
}
