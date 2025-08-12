locals {
  first_key = keys(var.function_apps)[0]
  rest_keys = [for k in keys(var.function_apps) : k if k != local.first_key]
}

# The first function app (creates the ASP)
module "functionapp_with_asp" {
  source                    = "git::https://github.com/terraform-azure-component-function-app?ref=v2.0.1"
  function_app_name         = var.function_apps[local.first_key].function_app_name
  environment               = var.environment
  location                  = var.location
  resource_group_name       = var.resource_group_name
  runtime_version           = var.runtime_version
  runtime_name              = var.runtime_name
  always_on                 = true
  create_service_plan       = true
  flex_consumption          = false
  vnet_route_all_enabled    = true
  subnet_id                 = var.subnet_id
  app_settings              = var.function_apps[local.first_key].app_settings
}

output "service_plan_id" {
  value = module.functionapp_with_asp.service_plan_id
}

# All subsequent function apps (reuse the ASP)
module "functionapp_without_asp" {
  for_each = toset(local.rest_keys)
  source                  = "git::https://github.com/VF-DigitalEngineering-CloudEngineering/terraform-azure-component-function-app?ref=v2.0.1"
  function_app_name       = var.function_apps[each.key].function_app_name
  environment             = var.environment
  location                = var.location
  resource_group_name     = var.resource_group_name
  runtime_version         = var.runtime_version
  runtime_name            = var.runtime_name
  always_on               = true
  create_service_plan     = false
  flex_consumption        = false
  vnet_route_all_enabled  = true
  subnet_id               = var.subnet_id
  app_service_plan = {
    id       = module.functionapp_with_asp.service_plan_id
    sku_name = "p0v3"
  }
  app_settings          = var.function_apps[each.key].app_settings
}
