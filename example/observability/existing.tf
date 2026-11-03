data "azurerm_resource_group" "monitoring" {
  name = var.resource_group_name
}
# Read only: AKS remains managed by its existing Terraform configuration.
# Read ARM properties, not cluster credentials; Helm uses the authorized kubeconfig.
data "azapi_resource" "aks" {
  type      = "Microsoft.ContainerService/managedClusters@2024-10-01"
  name      = var.aks_name
  parent_id = "/subscriptions/${var.subscription_id}/resourceGroups/${var.aks_resource_group_name}"
  response_export_values = [
    "properties.oidcIssuerProfile",
    "properties.securityProfile.workloadIdentity"
  ]
  lifecycle {
    postcondition {
      condition = try(
        self.output.properties.oidcIssuerProfile.enabled == true &&
        startswith(self.output.properties.oidcIssuerProfile.issuerURL, "https://") &&
        self.output.properties.securityProfile.workloadIdentity.enabled == true,
        false
      )
      error_message = "Enable OIDC and Workload Identity in the existing AKS configuration before applying observability."
    }
  }
}
