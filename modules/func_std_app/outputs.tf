output "deployment_status" {
  description = "Status of function code deployments"
  value = {
    zip_file_info = jsondecode(shell_script.function_zip.output)
    deployments = {
      for key, deployment in azapi_resource_action.zip_deploy : key => {
        function_app_name = var.function_app_names[key]
        function_app_id   = deployment.resource_id
        status           = "deployed"
        timestamp        = timestamp()
      }
    }
    app_settings_updated = {
      for key, settings in azapi_update_resource.function_app_settings : key => {
        function_app_name = var.function_app_names[key]
        status           = "configured"
        custom_settings  = lookup(var.app_settings, key, {})
      }
    }
  }
}

output "function_urls" {
  description = "URLs for deployed function apps"
  value = {
    for key, name in var.function_app_names : key => {
      function_app_name = name
      base_url         = "https://${name}.azurewebsites.net"
      http_trigger_url = "https://${name}.azurewebsites.net/api/HttpTrigger"
      timer_function   = "TimerTrigger (runs automatically every 5 minutes)"
    }
  }
}

output "storage_deployments" {
  description = "Information about ZIP files uploaded to storage"
  value = {
    for key, blob in azurerm_storage_blob.function_code_zip : key => {
      storage_account = blob.storage_account_name
      container      = blob.storage_container_name
      blob_name      = blob.name
      content_md5    = blob.content_md5
    }
  }
}
