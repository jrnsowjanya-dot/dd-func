variable "function_apps" {
  description = "Map of Function Apps to create"
  type = map(object({
    function_app_name = string
    app_settings      = map(string)
  }))
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to deploy into"
}

variable "location" {
  type        = string
  description = "Azure region to deploy into"
}

variable "runtime_version" {
  type        = string
  description = "Azure region to deploy into"
}

variable "runtime_name" {
  type        = string
  description = "Azure region to deploy into"
}

variable "sku_name" {
  type        = string
  default     = "P0v3"
  description = "Azure region to deploy into"
}

variable "environment" {
  type        = string
  description = "Azure region to deploy into"
}

variable "subnet_id" {
  type        = string
  description = "Subnet id of the vnet to deploy into"
}

# variable "source_code_path" {
#   description = "The local path to the function app's source code."
#   type        = string
# }

variable "storage_container_name" {
  description = "Storage container name to store the source code package."
  type        = string
  default     = null
}

variable "flex_consumption" {
  description = "Flag to check if flex consumption plan will be used"
  type        = bool
  default     = true
}

variable "create_service_plan" {
  description = "Flag to check if service plan should be created or not for standard function app"
  type        = bool
  default     = true
}
