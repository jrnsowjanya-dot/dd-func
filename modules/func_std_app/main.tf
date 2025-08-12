locals {
  # Directory and ZIP configuration
  source_directory = "functions"
  zip_name        = "logforwarder"
  
  # Calculate hash of all function files for change detection
  source_hash = sha256(join("", [
    for file in fileset("${path.module}/${local.source_directory}", "**/*") :
    filesha256("${path.module}/${local.source_directory}/${file}")
    if !contains(["*.zip", "*.log", "node_modules/**/*", ".git/**/*"], file)
  ]))
  
  # Parse the deployment mapping
  function_app_deployments = jsondecode(var.function_app_deployments_json)
}

# Create ZIP file using shell script provider
resource "shell_script" "function_zip" {
  lifecycle_commands {
    create = <<-EOF
      cd ${path.module}/${local.source_directory}
      zip -r ../${local.zip_name}.zip .
      echo "{\"md5\": \"$(md5sum ../${local.zip_name}.zip | awk '{print $1}')\", \"file_name\": \"${local.zip_name}\", \"file_name_full\": \"${local.zip_name}.zip\", \"source_hash\": \"${local.source_hash}\"}"
    EOF
    delete = "rm -f ${path.module}/${local.zip_name}.zip"
  }
  
  triggers = {
    source_hash = local.source_hash
  }
}

# Get storage account information for each function app
data "azurerm_storage_account" "func_storage" {
  for_each            = var.storage_account_names
  name                = each.value
  resource_group_name = var.resource_group_name
}

# Upload ZIP to each function app's storage account
resource "azurerm_storage_blob" "function_code_zip" {
  for_each = var.storage_account_names

  name                   = jsondecode(shell_script.function_zip.output)["file_name_full"]
  type                   = "Block"
  source                 = "${path.module}/${jsondecode(shell_script.function_zip.output)["file_name_full"]}"
  storage_account_name   = each.value
  storage_container_name = var.storage_container_name
  content_md5            = jsondecode(shell_script.function_zip.output)["md5"]

  lifecycle {
    replace_triggered_by = [shell_script.function_zip]
  }
  
  depends_on = [shell_script.function_zip]
}

# Deploy ZIP file to Function Apps using Azure REST API
resource "azapi_resource_action" "zip_deploy" {
  for_each    = var.function_app_ids
  type        = "Microsoft.Web/sites@2022-03-01"
  resource_id = each.value

  action = "zipdeploy"
  method = "POST"
  
  # Use the ZIP file content for deployment
  body = file("${path.module}/${jsondecode(shell_script.function_zip.output)["file_name_full"]}")
  
  depends_on = [
    shell_script.function_zip,
    azurerm_storage_blob.function_code_zip
  ]
}

# Update function app settings with custom app settings and proper runtime configuration
resource "azapi_update_resource" "function_app_settings" {
  for_each    = var.function_app_ids
  type        = "Microsoft.Web/sites/config@2022-03-01"
  resource_id = "${each.value}/config/appsettings"

  body = jsonencode({
    properties = merge(
      {
        # Core Function App settings
        FUNCTIONS_EXTENSION_VERSION     = "~4"
        FUNCTIONS_WORKER_RUNTIME        = "node"
        WEBSITE_NODE_DEFAULT_VERSION    = "~18"
        
        # Storage settings
        AzureWebJobsStorage = "DefaultEndpointsProtocol=https;AccountName=${var.storage_account_names[each.key]};AccountKey=${data.azurerm_storage_account.func_storage[each.key].primary_access_key};"
        
        # Performance and deployment settings
        WEBSITE_RUN_FROM_PACKAGE        = "0"
        WEBSITE_ENABLE_SYNC_UPDATE_SITE = "true"
        WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = "DefaultEndpointsProtocol=https;AccountName=${var.storage_account_names[each.key]};AccountKey=${data.azurerm_storage_account.func_storage[each.key].primary_access_key};"
        WEBSITE_CONTENTSHARE           = "${var.function_app_names[each.key]}-content"
      },
      # Merge with custom app settings passed from Terragrunt
      lookup(var.app_settings, each.key, {})
    )
  })

  depends_on = [azapi_resource_action.zip_deploy]
}
