terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "5.12.0" }
    azapi   = { source = "Azure/azapi", version = "2.13.0" }
    helm    = { source = "hashicorp/helm", version = "3.3.0" }
  }
  # Reuse the existing Terraform setup and provider configurations.
}
