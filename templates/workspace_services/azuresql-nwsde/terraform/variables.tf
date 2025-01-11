variable "workspace_id" {
  type = string
}

variable "tre_id" {
  type = string
}

variable "tre_resource_id" {
  type = string
}

variable "sql_sku" {
  type = string
}

variable "storage_gb" {
  type = number

  validation {
    condition     = var.storage_gb > 1 && var.storage_gb < 1024
    error_message = "The storage value is out of range."
  }
}

variable "arm_environment" {
  type = string
}

variable "auth_tenant_id" {
  type        = string
  description = "Used to authenticate into the AAD Tenant to create the AAD App"
}

variable "auth_client_id" {
  type        = string
  description = "Used to authenticate into the AAD Tenant to create the AAD App"
}

variable "auth_client_secret" {
  type        = string
  description = "Used to authenticate into the AAD Tenant to create the AAD App"
}

variable "azuresql_identity" {
  type        = string
  description = "User Managed Identity for the Azure SQL instance, please see create-azuresql-identity-readme.md on how to create"
}
