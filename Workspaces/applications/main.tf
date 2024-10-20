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
  customer_prefix     = var.application_prefix
  is_application      = true
  release_id          = var.release_id
  release_url         = var.release_url
  tier                = var.tier
  zone                = var.zone
  notification_emails = var.notification_emails
}

module "az_resourcegroup" {
  source          = "../../terraform-modules/azurerm/resourcegroup/"
  location        = var.location
  resource_prefix = module.az_globalvars.resource_prefix
  name            = "app"
  tier            = module.az_globalvars.tier
  tags            = module.az_globalvars.tags
}

module "az_appserviceplan" {
  source              = "../../terraform-modules/azurerm/appserviceplan/"
  location            = var.location
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix
  name                = "asp"
  tags                = module.az_globalvars.tags
  notification_emails = module.az_globalvars.notification_emails
  sku_tier            = var.app_service_plan_sku_tier
  sku_size            = var.app_service_plan_sku_size
  enable_autoscale    = var.app_service_enable_autoscale
  kind                = var.application_prefix == "nrdo" ? "Linux" : var.app_service_plan_kind
}

module "az_storageaccount" {
  source              = "../../terraform-modules/azurerm/storageaccount/"
  location            = var.location
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix
  name                = "sto"
  tags                = module.az_globalvars.tags
  create_container    = var.storage_account_create_container
  container_name      = var.storage_account_container_name
  account_tier        = var.storage_account_tier
  replication_type    = var.storage_account_replication_type
}

module "az_keyvault" {
  source                     = "../../terraform-modules/azurerm/keyvault/"
  location                   = var.location
  resource_group_name        = module.az_resourcegroup.name
  resource_prefix            = module.az_globalvars.resource_prefix
  name                       = "kvl"
  tags                       = module.az_globalvars.tags
  sku_name                   = var.key_vault_sku_name
  generate-dataprotectionkey = true
  diagnostics_map            = local.diagnostics_map
}

module "az_applicationinsights" {
  source              = "../../terraform-modules/azurerm/applicationinsights/"
  location            = var.location
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix
  name                = "ain"
  tags                = module.az_globalvars.tags
}

module "az_appservice" {
  source                   = "../../terraform-modules/azurerm/appservice_linux/"
  location                 = var.location
  resource_group_name      = module.az_resourcegroup.name
  resource_prefix          = module.az_globalvars.resource_prefix
  names                    = var.web_app_names
  tags                     = module.az_globalvars.tags
  app_service_plan_name    = module.az_appserviceplan.name
  apin_instrumentation_key = module.az_applicationinsights.instrumentation_key
  diagnostics_map          = local.diagnostics_map
  sku_tier                 = var.app_service_plan_sku_tier
}

module "az_functionapp" {
  source                   = "../../terraform-modules/azurerm/functionapp_linux/"
  location                 = var.location
  resource_group_name      = module.az_resourcegroup.name
  resource_prefix          = module.az_globalvars.resource_prefix
  names                    = var.function_app_names
  tags                     = module.az_globalvars.tags
  app_service_plan_name    = module.az_appserviceplan.name
  storage_account_name     = module.az_storageaccount.name
  apin_instrumentation_key = module.az_applicationinsights.instrumentation_key
  diagnostics_map          = local.diagnostics_map
  deploy_function_app      = var.deploy_function_app
  function_app_version     = var.function_app_version
}

module "az_sqlserver" {
  source                                    = "../../terraform-modules/azurerm/sqlserver/"
  location                                  = var.location
  resource_group_name                       = module.az_resourcegroup.name
  resource_prefix                           = module.az_globalvars.resource_prefix
  tags                                      = module.az_globalvars.tags
  notification_emails                       = module.az_globalvars.notification_emails
  administrator_password                    = var.sql_administrator_password
  database_names                            = ["${title(var.application_prefix)}DB"]
  database_edition                          = var.sql_database_edition
  database_requested_service_objective_name = var.sql_database_requested_service_objective_name
  diagnostics_map                           = local.diagnostics_map
}

module "az_rediscache" {
  source              = "../../terraform-modules/azurerm/rediscache/"
  location            = var.location
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix
  name                = "rds"
  tags                = module.az_globalvars.tags
  sku_name            = var.redis_cache_sku_name
  capacity            = var.redis_cache_sku_capacity
  diagnostics_map     = local.diagnostics_map
  enabled             = var.application_prefix == "nrdo" ? true : false
}

module "az_relay" {
  source                  = "../../terraform-modules/azurerm/relay/"
  location                = var.location
  resource_group_name     = module.az_resourcegroup.name
  resource_prefix         = module.az_globalvars.resource_prefix
  name                    = "rly"
  tags                    = module.az_globalvars.tags
  diagnostics_map         = local.diagnostics_map
  hybrid_connection_names = contains(local.relay_enabled_apps, var.application_prefix) ? local.relay_hybrid_connections : ""
  enabled                 = contains(local.relay_enabled_apps, var.application_prefix) ? true : false
}

resource "azurerm_role_assignment" "appservice-relaynamespace-management-role-assignment" {
  count                = contains(local.relay_enabled_apps, var.application_prefix)? 1 : 0
  scope                = module.az_relay.id
  principal_id         = module.az_appservice.app_principal_ids["${module.az_globalvars.resource_prefix}app"]
  role_definition_name = "Azure Relay Owner"
}

resource "azurerm_key_vault_secret" "relay-management-settings" {
  count        = contains(local.relay_enabled_apps, var.application_prefix)? 1 : 0
  name         = var.relay_management_option_name
  value        = join(";", ["RelayNamespace=${module.az_relay.name}", 
                            "SubscriptionId=${module.az_appservice.app_principal_ids["${module.az_globalvars.resource_prefix}app"]}", 
                            "ResourceGroupName=${module.az_resourcegroup.name}"])
  key_vault_id = module.az_keyvault.id
}

module "az_actiongroup" {
  source              = "../../terraform-modules/azurerm/monitor/actiongroup/"
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix_shared
  tags                = module.az_globalvars.tags
  short_name          = var.project
  enabled             = var.alerts_enabled
  notification_emails = module.az_globalvars.notification_emails
}

module "az_metricalert_database_storage_alert" {
  source              = "../../terraform-modules/azurerm/monitor/metricalert"
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix
  tags                = module.az_globalvars.tags
  name                = "db-storage-alert"
  resource_ids        = module.az_sqlserver.id
  action_group_id     = module.az_actiongroup.id
  enabled             = var.alerts_enabled
  description         = "Alert: High Database Storage Alert"
  frequency           = "PT15M"
  window_size         = "PT15M"
  metric_namespace    = "Microsoft.Sql/servers/databases"
  metric_name         = "storage_percent"
  aggregation         = "Average"
  operator            = "GreaterThan"
  threshold           = 90
}

module "az_metricalert_database_cpu_alert" {
  source              = "../../terraform-modules/azurerm/monitor/metricalert"
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix
  tags                = module.az_globalvars.tags
  name                = "db-cpu-alert"
  resource_ids        = module.az_sqlserver.id
  action_group_id     = module.az_actiongroup.id
  enabled             = var.alerts_enabled
  description         = "Alert: High Database CPU Alert"
  frequency           = "PT15M"
  window_size         = "PT15M"
  metric_namespace    = "Microsoft.Sql/servers/databases"
  metric_name         = "cpu_percent"
  aggregation         = "Average"
  operator            = "GreaterThan"
  threshold           = 90
}

module "az_metricalert_appservice_cpu_alert" {
 source              = "../../terraform-modules/azurerm/monitor/metricalert"
 resource_group_name = module.az_resourcegroup.name
 resource_prefix     = module.az_globalvars.resource_prefix
 tags                = module.az_globalvars.tags
 name                = "cpu-appserviceplan-alert"
 resource_ids        = module.az_appserviceplan.id
 action_group_id     = module.az_actiongroup.id
 enabled             = var.alerts_enabled
 description         = "cpu-appserviceplan-alert"
 frequency           = "PT1M"
 window_size         = "PT5M"
 metric_namespace    = "Microsoft.Web/serverfarms"
 metric_name         = "CpuPercentage"
 aggregation         = "Average"
 operator            = "GreaterThan"
 threshold           = 90
}