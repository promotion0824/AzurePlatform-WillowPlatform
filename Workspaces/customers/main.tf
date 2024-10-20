## data sources
data "azurerm_subscription" "subscription" {}

data "terraform_remote_state" "shared" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state-resource-group-name
    storage_account_name = var.state-storage-account-name
    sas_token            = var.state-storage-account-sas-token
    container_name       = "terraform-state"
    key                  = "${terraform.workspace}/${var.project}/${var.location}/terraform_t2_z${var.zone}_shared.tfstateenv:${terraform.workspace}"
  }
}

module "az_globalvars" {
  source              = "../../terraform-modules/azurerm/global_variables/"
  location            = var.location
  project             = var.project
  project_prefix      = var.project_prefix
  customer_prefix     = var.customer_prefix
  release_id          = var.release_id
  release_url         = var.release_url
  tier                = var.tier
  zone                = var.zone
  notification_emails = var.notification_emails
}

data "azurerm_resource_group" "rg" {
  count = var.skip_iot_resource_group_creation == true ? 1 : 0
  name  = "t${module.az_globalvars.tier}-${module.az_globalvars.resource_prefix}app-rsg"
}

resource "azurerm_resource_group" "rg" {
  count    = var.skip_iot_resource_group_creation == false ? 1 : 0
  name     = "t${module.az_globalvars.tier}-${module.az_globalvars.resource_prefix}app-rsg"
  location = var.location
  tags     = module.az_globalvars.tags
}

locals {
  resource_group_name = var.skip_iot_resource_group_creation == true ? data.azurerm_resource_group.rg[0].name : azurerm_resource_group.rg[0].name
}

module "az_storageaccount" {
  source              = "../../terraform-modules/azurerm/storageaccount/"
  location            = var.location
  resource_group_name = local.resource_group_name
  resource_prefix     = module.az_globalvars.resource_prefix
  name                = "iot"
  tags                = module.az_globalvars.tags
  create_container    = var.storage_account_create_container
  container_name      = var.storage_account_container_name
  account_tier        = var.storage_account_tier
  replication_type    = var.storage_account_replication_type
}

 module "az_eventhub_saj" {
   source              = "../../terraform-modules/azurerm/eventhub/"
   location            = var.location
   resource_group_name = local.resource_group_name
   resource_prefix     = module.az_globalvars.resource_prefix
   name                = "saj"
   event_hubs = [
     {
       name              = "input-to-lda"
       partitions        = var.eventhub_partition
       message_retention = var.eventhub_message_retention
       consumers = [
         # "app1"
       ]
       keys = [
         # {
         #   name   = "app1"
         #   listen = true
         #   send   = true
         # }
       ]
     }
   ]
   network_rules = {
     ip_rules = []
     subnet_ids = []
   }
   tags               = module.az_globalvars.tags
   diagnostics_map    = local.diagnostics_map
   retention_in_days  = 0
 }

module "az_appserviceplan" {
  source              = "../../terraform-modules/azurerm/appserviceplan/"
  location            = var.location
  resource_group_name = local.resource_group_name
  resource_prefix     = module.az_globalvars.resource_prefix
  name                = "asp"
  tags                = module.az_globalvars.tags
  notification_emails = module.az_globalvars.notification_emails
  sku_tier            = var.app_service_plan_sku_tier
  sku_size            = var.app_service_plan_sku_size
  enable_autoscale    = var.app_service_enable_autoscale
}

module "az_applicationinsights" {
  source              = "../../terraform-modules/azurerm/applicationinsights/"
  location            = var.location
  resource_group_name = local.resource_group_name
  resource_prefix     = module.az_globalvars.resource_prefix
  name                = "ain"
  tags                = module.az_globalvars.tags
}

module "az_functionapp" {
  source                   = "../../terraform-modules/azurerm/functionapp/"
  location                 = var.location
  resource_group_name      = local.resource_group_name
  resource_prefix          = module.az_globalvars.resource_prefix
  names                    = var.function_app_names
  tags                     = module.az_globalvars.tags
  app_service_plan_name    = module.az_appserviceplan.name
  storage_account_name     = module.az_storageaccount.name
  apin_instrumentation_key = module.az_applicationinsights.instrumentation_key
  diagnostics_map          = local.diagnostics_map
  retention_in_days        = 0 
  deploy_function_app      = var.deploy_function_app
}

module "az_iothub" {
  source                                 = "../../terraform-modules/azurerm/iothub/"
  location                               = var.location
  resource_group_name                    = local.resource_group_name
  resource_prefix                        = module.az_globalvars.resource_prefix
  name                                   = "iot"
  tags                                   = module.az_globalvars.tags
  sku_name                               = local.iot_hub_sku_name
  sku_capacity                           = local.iot_hub_sku_capacity
  storage_primary_blob_connection_string = module.az_storageaccount.primary_blob_connection_string
  storage_container_name                 = var.storage_account_container_name
  encoding                               = "Json"
  diagnostics_map                        = local.diagnostics_map
  retention_in_days                      = 0
}

module "az_metricalert_iot_total_messages_used" {
  source              = "../../terraform-modules/azurerm/monitor/metricalert/"
  resource_group_name = local.resource_group_name
  resource_prefix     = module.az_globalvars.resource_prefix
  tags                = module.az_globalvars.tags
  name                = "iot-total-messages-used"
  resource_ids        = module.az_iothub.id
  action_group_id     = local.shared_action_group_id
  enabled             = var.alerts_enabled
  severity            = 1
  description         = "Alert: IoT hub total messages quota"
  frequency           = "PT30M"
  window_size         = "PT30M"
  metric_namespace    = "Microsoft.Devices/IotHubs"
  metric_name         = "dailyMessageQuotaUsed"
  aggregation         = "Average"
  operator            = "GreaterThan"
  threshold           = local.iot_alert_total_messages_used_threshold
}

module "az_metricalert_iot_telemetry_messages_sent" {
  source              = "../../terraform-modules/azurerm/monitor/metricalert/"
  resource_group_name = local.resource_group_name
  resource_prefix     = module.az_globalvars.resource_prefix
  tags                = module.az_globalvars.tags
  name                = "iot-telemetry-messages-sent"
  resource_ids        = module.az_iothub.id
  action_group_id     = local.shared_action_group_id
  enabled             = var.alerts_enabled
  severity            = 1
  description         = "Alert: IoT hub telemetry messages dropped"
  frequency           = "PT30M"
  window_size         = "PT30M"
  metric_namespace    = "Microsoft.Devices/IotHubs"
  metric_name         = "d2c.telemetry.ingress.success"
  aggregation         = "Total"
  operator            = "LessThan"
  threshold           = 1
}
