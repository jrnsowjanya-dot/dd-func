variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "function_app_names" {
  description = "Map of function app keys to their actual names (from dependency output)"
  type        = map(string)
}

variable "function_app_ids" {
  description = "Map of function app keys to their resource IDs (from dependency output)"
  type        = map(string)
}

variable "storage_account_names" {
  description = "Map of function app keys to their storage account names (from dependency output)"
  type        = map(string)
}

variable "storage_container_name" {
  description = "Name of the storage container for function deployment files"
  type        = string
}

variable "function_app_deployments_json" {
  description = "JSON string mapping function app names to storage account names"
  type        = string
}

variable "app_settings" {
  description = "Map of function app keys to their custom app settings"
  type        = map(map(string))
  default     = {}
}
