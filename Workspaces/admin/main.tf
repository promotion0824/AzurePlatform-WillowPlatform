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
}
