locals {
  # Directory containing the function code and name of the zip package
  source_directory = "functions"
  zip_name         = "logforwarder.zip"

  # Decode function app to storage account mapping (kept for compatibility)
  function_app_deployments = jsondecode(var.function_app_deployments_json)
}

######################################################################
# Package the function code
######################################################################

# Create a ZIP archive from the local function directory. The archive
# is recreated whenever the source files change, which avoids the need
# for external null_resource triggers.
data "archive_file" "function_zip" {
  type        = "zip"
  source_dir  = "${path.module}/${local.source_directory}"
  output_path = "${path.module}/${local.zip_name}"
}

######################################################################
# Upload ZIP package to all storage accounts
######################################################################

data "azurerm_storage_account" "func_storage" {
  for_each            = var.storage_account_names
  name                = each.value
  resource_group_name = var.resource_group_name
}

# Upload the generated ZIP file to each storage account. The MD5 hash
# ensures the blob is replaced when the archive changes.
resource "azurerm_storage_blob" "function_code_zip" {
  for_each = var.storage_account_names

  name                   = local.zip_name
  type                   = "Block"
  source                 = data.archive_file.function_zip.output_path
  storage_account_name   = each.value
  storage_container_name = var.storage_container_name
  content_md5            = filemd5(data.archive_file.function_zip.output_path)
}

######################################################################
# Generate SAS URLs for the uploaded packages
######################################################################

data "azurerm_storage_account_sas" "package_sas" {
  for_each           = var.storage_account_names
  connection_string  = data.azurerm_storage_account.func_storage[each.key].primary_connection_string
  https_only         = true

  resource_types {
    service   = "b"
    container = "c"
    object    = "o"
  }

  services {
    blob = "b"
  }

  start  = "2020-01-01"
  expiry = "2030-01-01"

  permissions {
    read   = true
    list   = true
  }
}

locals {
  # Construct SAS-protected URLs to the uploaded ZIP packages
  run_from_package = {
    for key, name in var.function_app_names :
    key => "https://${var.storage_account_names[key]}.blob.core.windows.net/${var.storage_container_name}/${azurerm_storage_blob.function_code_zip[key].name}${data.azurerm_storage_account_sas.package_sas[key].sas}"
  }
}

######################################################################
# Update Function App settings to run from the uploaded package
######################################################################

resource "azapi_update_resource" "function_app_settings" {
  for_each    = var.function_app_ids
  type        = "Microsoft.Web/sites/config@2022-03-01"
  resource_id = "${each.value}/config/appsettings"

  body = jsonencode({
    properties = merge(
      {
        FUNCTIONS_EXTENSION_VERSION     = "~4"
        FUNCTIONS_WORKER_RUNTIME        = "node"
        WEBSITE_NODE_DEFAULT_VERSION    = "~18"
        AzureWebJobsStorage             = "DefaultEndpointsProtocol=https;AccountName=${var.storage_account_names[each.key]};AccountKey=${data.azurerm_storage_account.func_storage[each.key].primary_access_key};"
        WEBSITE_RUN_FROM_PACKAGE        = local.run_from_package[each.key]
        WEBSITE_ENABLE_SYNC_UPDATE_SITE = "true"
        WEBSITE_CONTENTAZUREFILECONNECTIONSTRING = "DefaultEndpointsProtocol=https;AccountName=${var.storage_account_names[each.key]};AccountKey=${data.azurerm_storage_account.func_storage[each.key].primary_access_key};"
        WEBSITE_CONTENTSHARE           = "${var.function_app_names[each.key]}-content"
        BlobConnection__serviceUri     = "https://${var.storage_account_names[each.key]}.blob.core.windows.net"
        BlobConnection__credential     = "managedidentity"
      },
      lookup(var.app_settings, each.key, {})
    )
  })
}

