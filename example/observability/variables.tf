variable "name" {
  description = "Short unique prefix for the new monitoring resources."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,23}$", var.name))
    error_message = "Use 3-24 lowercase letters, digits or hyphens, starting with a letter."
  }
}
variable "subscription_id" { type = string }
variable "tenant_id" { type = string }
variable "resource_group_name" {
  description = "Existing resource group for the new monitoring resources."
  type        = string
}
variable "aks_name" { type = string }
variable "aks_resource_group_name" { type = string }
variable "grafana_admin_secret_name" {
  description = "Existing Kubernetes Secret in observability, with admin-user and admin-password keys."
  type        = string
  default     = "grafana-admin"
}
