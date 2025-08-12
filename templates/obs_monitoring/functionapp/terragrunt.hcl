terraform {
  source = "${get_repo_root()}/modules/func_std"
 }

include "root" {
  path   = find_in_parent_folders()
  expose = true
}

locals {
  vars = include.root.locals.vars
}

dependency "data_prereqs" {
  config_path = "../../data_prereqs"

  mock_outputs = {
    tooling_obs_mon_rg_name = "mock-rg-name"
    tooling_network_rg_resource_id = "mock-vnet-rg-id"
    tooling_key_vault_secrets  = {}
  }
}

dependency "event_hub" {
  config_path = "../../event_hub"
  mock_outputs = {
    event_hub_namespace_connection_string = "mock-event_hub_namespace_connection_string"
    event_hub_namespace_id                = "mock-event_hub_namespace_id"
    event_hub_namespace_name              = "mock-event_hub_namespace_name"
    event_hub_names = [
      "mock-event_hub_name1",
      "mock-event_hub_name2"
    ]
    }
  }

  dependency "vnet" {
  config_path = "../../spoke/vnet"
  mock_outputs = {
    vnet_name = "mock-spoke-vnet-name"
    subnet_ids = {
      "snet-functions"        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock-rg/providers/Microsoft.Network/virtualNetworks/mock-vnet/subnets/dev-snet"
     }
  }
}

inputs = {
  resource_group_name            = dependency.data_prereqs.outputs.tooling_obs_mon_rg_name
  location                       = local.vars.region
  environment                    = "mgmt"
  runtime_name                   = "node"
  runtime_version                = "20"
  vnet_route_all_enabled         = true
  subnet_id                      = dependency.vnet.outputs.subnet_ids["snet-functions"]
  always_ready                   = true
  always_ready_instance_count    = 1
  flex_consumption               = false
  create_service_plan            = true
  storage_container_name         = local.vars.func_storage_container_name
  always_on                      = true
  function_apps = {
    "plt-log-func" = {
      function_app_name              = local.vars.obs_mon_plt_func_name
      app_settings                   = {
        WEBSITE_RUN_FROM_PACKAGE     = "1" 
        EventHubConnection           = dependency.event_hub.outputs.event_hub_namespace_connection_string
        event_hub_namespace_name     = dependency.event_hub.outputs.event_hub_namespace_name
        SharedAccessKeyName          = local.vars.eventhub_ns_saskey
        eventHubName                 = dependency.event_hub.outputs.event_hub_names[0]
        DD_API_KEY                   = dependency.data_prereqs.outputs.tooling_key_vault_secrets["${local.vars.tooling_kv_name}-${local.vars.plt-dd-secret}"].primary_api_key
        DD_SITE                      = dependency.data_prereqs.outputs.tooling_key_vault_secrets["${local.vars.tooling_kv_name}-${local.vars.plt-dd-secret}"].api_domain 
      }
    }
    "tnt-log-func" = {
      function_app_name              = local.vars.obs_mon_tnt_func_name
      app_settings                   = {
        WEBSITE_RUN_FROM_PACKAGE     = "1"
        DD_API_KEY                   = dependency.data_prereqs.outputs.tooling_key_vault_secrets["${local.vars.tooling_kv_name}-${local.vars.tnt-dd-secret}"].primary_api_key
        DD_SITE                      = dependency.data_prereqs.outputs.tooling_key_vault_secrets["${local.vars.tooling_kv_name}-${local.vars.tnt-dd-secret}"].api_domain   
        EventHubConnection           = dependency.event_hub.outputs.event_hub_namespace_connection_string
        event_hub_namespace_name     = dependency.event_hub.outputs.event_hub_namespace_name
        SharedAccessKeyName          = local.vars.eventhub_ns_saskey
        eventHubName                 = dependency.event_hub.outputs.event_hub_names[1]
      }
    }
  }
}


