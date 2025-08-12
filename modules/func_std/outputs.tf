output "function_app_names" {
  value = merge(
    { (local.first_key) = module.functionapp_with_asp.name },
    { for k in local.rest_keys : k => module.functionapp_without_asp[k].name }
  )
}

output "storage_account_names" {
  value = merge(
    { (local.first_key) = module.functionapp_with_asp.storage_account_name },
    { for k in local.rest_keys : k => module.functionapp_without_asp[k].storage_account_name }
  )
}

output "function_app_ids" {
  value = merge(
    { (local.first_key) = module.functionapp_with_asp.id },
    { for k in local.rest_keys : k => module.functionapp_without_asp[k].id }
  )
}
