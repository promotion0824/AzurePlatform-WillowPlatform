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
  source                     = "../../terraform-modules/azurerm/appserviceplan/"
  location                   = var.location
  resource_group_name        = module.az_resourcegroup.name
  resource_prefix            = module.az_globalvars.resource_prefix
  name                       = "asp"
  tags                       = module.az_globalvars.tags
  notification_emails        = module.az_globalvars.notification_emails
  sku_tier                   = var.app_service_plan_sku_tier_livedata
  sku_size                   = var.app_service_plan_sku_size_livedata
  enable_autoscale           = var.app_service_enable_autoscale
  autoscale_maximum_capacity = var.app_service_autoscale_maximum_capacity_livedata
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
  source              = "../../terraform-modules/azurerm/keyvault/"
  location            = var.location
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix
  name                = "kvl"
  tags                = module.az_globalvars.tags
  sku_name            = var.key_vault_sku_name
  diagnostics_map     = local.diagnostics_map
}

module "az_applicationinsights" {
  source              = "../../terraform-modules/azurerm/applicationinsights/"
  location            = var.location
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix
  name                = "ain"
  tags                = module.az_globalvars.tags
}

module "az_functionapp" {
  source                   = "../../terraform-modules/azurerm/functionapp/"
  location                 = var.location
  resource_group_name      = module.az_resourcegroup.name
  resource_prefix          = module.az_globalvars.resource_prefix
  names                    = var.function_app_names
  tags                     = module.az_globalvars.tags
  function_app_version     = var.function_app_version
  app_service_plan_name    = module.az_appserviceplan.name
  storage_account_name     = module.az_storageaccount.name
  apin_instrumentation_key = module.az_applicationinsights.instrumentation_key
  diagnostics_map          = local.diagnostics_map
  deploy_function_app      = var.deploy_function_app
}

module "az_appservice" {
  source                   = "../../terraform-modules/azurerm/appservice/"
  location                 = var.location
  resource_group_name      = module.az_resourcegroup.name
  resource_prefix          = module.az_globalvars.resource_prefix
  names                    = var.web_app_names
  tags                     = module.az_globalvars.tags
  app_service_plan_name    = module.az_appserviceplan.name
  apin_instrumentation_key = module.az_applicationinsights.instrumentation_key
  key_vault_name           = module.az_keyvault.name
  diagnostics_map          = local.diagnostics_map
  sku_tier                 = var.app_service_plan_sku_tier_livedata
}

module "az_sqlserver" {
  source                                    = "../../terraform-modules/azurerm/sqlserver/"
  location                                  = var.location
  resource_group_name                       = module.az_resourcegroup.name
  resource_prefix                           = module.az_globalvars.resource_prefix
  tags                                      = module.az_globalvars.tags
  notification_emails                       = module.az_globalvars.notification_emails
  administrator_password                    = var.sql_administrator_password
  database_names                            = var.sql_database_names
  database_edition                          = var.sql_database_edition_livedata
  database_requested_service_objective_name = var.sql_database_requested_service_objective_name_livedata
  diagnostics_map                           = local.diagnostics_map
  ##aad_admin_login_name                      = "IoT-SqlAdmin-Nonprod"
  ##aad_admin_login_name                      = "IoT-SqlAdmin-Prod"
  aad_admin_login_name                      = var.aad_admin_login_name
}

# ConnectorCore service bus
resource "azurerm_servicebus_namespace" "sbns" {
  name                = "wil-${module.az_globalvars.env_prefix}-iot-${module.az_globalvars.location_with_zone_prefix}-sbns"
  resource_group_name = module.az_resourcegroup.name
  location            = var.location
  tags                = module.az_globalvars.tags
  sku                 = "Standard"
}

/**********************************************************************************************/
# Create forwarding function app per region to forward from service bus to deployment dashboard
locals {
  iot_res_prefix = "${module.az_globalvars.company_prefix}-${module.az_globalvars.env_prefix}-iot-${module.az_globalvars.location_with_zone_prefix}-"
  function_app_names = [
    "fwddeployment-func",
  ]
}

module "az_forwarding_functionapp" {
  source                   = "../../terraform-modules/azurerm/functionapp/"
  location                 = var.location
  resource_group_name      = module.az_resourcegroup.name
  resource_prefix          = local.iot_res_prefix
  names                    = local.function_app_names
  tags                     = module.az_globalvars.tags
  function_app_version     = "~4"
  app_service_plan_name    = module.az_appserviceplan.name
  storage_account_name     = module.az_storageaccount.name
  apin_instrumentation_key = module.az_applicationinsights.instrumentation_key
  diagnostics_map          = local.diagnostics_map
  deploy_function_app      = true
}

# Add subscription to service bus to listen for the function app
resource "azurerm_servicebus_subscription" "subscription" {
  name                = "deployment-forward-func-sub"
  max_delivery_count  = 1
  topic_name          = "deployment-dashboard-connectorupdates"
  namespace_name      = azurerm_servicebus_namespace.sbns.name
  resource_group_name = module.az_resourcegroup.name
}

# Add Service Bus Listener role to the function app
resource "azurerm_role_assignment" "servicebus_listener" {
  scope                = azurerm_servicebus_namespace.sbns.id
  role_definition_name = "Azure Service Bus Data Receiver"
  
  for_each = {
    for i, v in module.az_forwarding_functionapp.principal_ids : i => v
  }
  principal_id         = each.value
}

/**********************************************************************************************/
# Create notification resolver function app per region
locals {
   notification_function_app_names = [
    "notification-resolver-func",
  ]
}

module "az_notification_functionapp" {
  source                   = "../../terraform-modules/azurerm/functionapp/"
  location                 = var.location
  resource_group_name      = module.az_resourcegroup.name
  resource_prefix          = local.iot_res_prefix
  names                    = local.notification_function_app_names
  tags                     = module.az_globalvars.tags
  function_app_version     = "~4"
  app_service_plan_name    = module.az_appserviceplan.name
  storage_account_name     = module.az_storageaccount.name
  apin_instrumentation_key = module.az_applicationinsights.instrumentation_key
  diagnostics_map          = local.diagnostics_map
  deploy_function_app      = true
}

# Add Service Bus Listener role to the function app
resource "azurerm_role_assignment" "servicebus_listener_notification" {
  scope                = azurerm_servicebus_namespace.sbns.id
  role_definition_name = "Azure Service Bus Data Owner"

  for_each = {
    for i, v in module.az_notification_functionapp.principal_ids : i => v
  }
  principal_id         = each.value
}