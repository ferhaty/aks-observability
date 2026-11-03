variable "name" {
  description = "Short unique prefix for resources owned by this module."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,23}$", var.name))
    error_message = "Use 3-24 lowercase letters, digits or hyphens, starting with a letter."
  }
}
variable "resource_group_name" { type = string }
variable "resource_group_id" { type = string }
variable "location" {
  description = "Same Azure public-cloud region as AKS; approve native OTLP availability before deployment. Pass the owner's location input, NOT a cluster attribute (avoids a dependency cycle)."
  type        = string
}
variable "tenant_id" { type = string }
variable "subscription_id" { type = string }
variable "aks_id" { type = string }
variable "oidc_issuer_url" {
  type = string
  validation {
    condition     = startswith(var.oidc_issuer_url, "https://")
    error_message = "Use the AKS resource's exact HTTPS OIDC issuer, including its trailing slash."
  }
}
