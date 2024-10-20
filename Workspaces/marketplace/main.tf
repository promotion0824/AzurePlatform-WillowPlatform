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

data "terraform_remote_state" "platform" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state-resource-group-name
    storage_account_name = var.state-storage-account-name
    sas_token            = var.state-storage-account-sas-token
    container_name       = "terraform-state"
    key                  = "${terraform.workspace}/${var.project}/${var.location}/terraform_t${var.tier}_z${var.zone}_platform.tfstateenv:${terraform.workspace}"
  }
}

data "terraform_remote_state" "livedata" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.state-resource-group-name
    storage_account_name = var.state-storage-account-name
    sas_token            = var.state-storage-account-sas-token
    container_name       = "terraform-state"
    key                  = "${terraform.workspace}/${var.project}/${var.location}/terraform_t${var.tier}_z${var.zone}_livedata.tfstateenv:${terraform.workspace}"
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
  source              = "../../terraform-modules/azurerm/appserviceplan/"
  location            = var.location
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix
  name                = "asp"
  tags                = module.az_globalvars.tags
  sku_tier            = var.app_service_plan_sku_tier
  sku_size            = var.app_service_plan_sku_size
  enable_autoscale    = var.app_service_enable_autoscale
  kind				  = var.app_service_plan_kind
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
  secrets = merge(
    lookup(local.keyvault_secrets, "shared", {}),
    lookup(local.keyvault_secrets, module.az_globalvars.location_prefix, {})
  )
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
  app_settings             = local.app_settings
}

module "az_sqlserver" {
  source                                    = "../../terraform-modules/azurerm/sqlserver/"
  location                                  = var.location
  resource_group_name                       = module.az_resourcegroup.name
  resource_prefix                           = module.az_globalvars.resource_prefix
  tags                                      = module.az_globalvars.tags
  administrator_password                    = var.sql_administrator_password
  database_names                            = var.sql_database_names
  database_edition                          = var.sql_database_edition
  database_requested_service_objective_name = var.sql_database_requested_service_objective_name
  database_zone_redundant                   = var.sql_database_zone_redundant
  diagnostics_map                           = local.diagnostics_map
  ##aad_admin_login_name                    = "Marketplace-SqlAdmin-Nonprod"
  ##aad_admin_login_name                    = "Marketplace-SqlAdmin-Prod"
  aad_admin_login_name                      = var.aad_admin_login_name
}

module "az_servicebus" {
  source                          = "../../terraform-modules/azurerm/servicebus/"
  location                        = var.location
  resource_group_name             = module.az_resourcegroup.name
  resource_prefix                 = module.az_globalvars.resource_prefix
  tags                            = module.az_globalvars.tags
  namespace_sku                   = var.servicebus_namespace_sku
  queues                          = var.servicebus_queues
  topics                          = var.servicebus_topics
  queue_max_size_in_megabytes     = var.servicebus_queue_max_size_in_megabytes
  subscription_max_delivery_count = var.servicebus_subscription_max_delivery_count
  diagnostics_map                 = local.diagnostics_map
}