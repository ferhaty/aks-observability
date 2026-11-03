terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "5.12.0" }
    helm    = { source = "hashicorp/helm", version = "3.3.0" }
  }
  # Retain the backend configuration owned by your existing pipeline.
}
provider "azurerm" {
  features {}
  subscription_id                 = var.environment.subscription_id
  resource_provider_registrations = "none"
}
variable "environment" {
  description = "Owner-supplied resources and an already authorized kubeconfig; no cluster is created or imported."
  type = object({
    subscription_id      = string
    tenant_id            = string
    resource_group_name  = string
    location             = string
    oidc_issuer_url      = string
    trace_dcr_id         = string
    trace_endpoint       = string
    monitor_workspace_id = string
    prometheus_query_url = string
    kubeconfig_path      = string
    kubeconfig_context   = string
  })
  validation {
    condition     = startswith(var.environment.oidc_issuer_url, "https://") && startswith(var.environment.trace_endpoint, "https://") && endswith(var.environment.trace_endpoint, "/streams/Microsoft-OTLP-Traces/otlp/v1/traces")
    error_message = "Use the existing HTTPS issuer and the full Azure OTLP trace endpoint from the owner's connection information."
  }
  validation {
    condition     = startswith(var.environment.prometheus_query_url, "https://")
    error_message = "Use the owner-approved HTTPS Prometheus query endpoint of the Azure Monitor workspace."
  }
}
variable "grafana_admin_secret_name" {
  description = "Existing Kubernetes Secret in observability, with admin-user and admin-password keys."
  type        = string
  default     = "grafana-admin"
}
provider "helm" {
  kubernetes = {
    config_path    = var.environment.kubeconfig_path
    config_context = var.environment.kubeconfig_context
  }
}
