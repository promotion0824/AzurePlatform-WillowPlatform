## data sources
data "azurerm_subscription" "subscription" {}

module "az_globalvars" {
  #   source          = "../modules/azurerm/global_variables/"
  #   source          = "git::ssh://git@ssh.dev.azure.com/v3/willowdev/AzurePlatform/terraform-azurerm//global_variables"
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

module "az_resourcegroup" {
  source          = "../../terraform-modules/azurerm/resourcegroup/"
  location        = var.location
  resource_prefix = module.az_globalvars.resource_prefix_shared
  name            = "mgt"
  tier            = module.az_globalvars.tier
  tags            = module.az_globalvars.tags
}

module "az_storageaccount" {
  source              = "../../terraform-modules/azurerm/storageaccount/"
  location            = var.location
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix_shared
  name                = "sto"
  tags                = module.az_globalvars.tags
  create_container    = var.storage_account_create_container
  container_name      = var.storage_account_container_name
  account_tier        = var.storage_account_tier
  replication_type    = var.storage_account_replication_type
}

module "az_keyvault" {
  source                           = "../../terraform-modules/azurerm/keyvault/"
  location                         = var.location
  resource_group_name              = module.az_resourcegroup.name
  resource_prefix                  = module.az_globalvars.resource_prefix_shared
  name                             = "kvl"
  tags                             = module.az_globalvars.tags
  sku_name                         = var.key_vault_sku_name
}
