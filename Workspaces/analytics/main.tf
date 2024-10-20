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

module "az_storageaccount" {
  source                 = "../../terraform-modules/azurerm/storageaccount/"
  location               = var.location
  resource_group_name    = module.az_resourcegroup.name
  resource_prefix        = module.az_globalvars.resource_prefix
  name                   = "analytics"
  tags                   = module.az_globalvars.tags
  create_container       = var.storage_account_create_container
  container_name         = var.storage_account_container_name
  account_tier           = var.storage_account_tier
  replication_type       = var.storage_account_replication_type
  enable_data_protection = var.storage_account_enable_data_protection
  retention_in_days      = var.storage_account_retention_days
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
  diagnostics_map                           = local.diagnostics_map
}

module "az_datafactory" {
  source               = "../../terraform-modules/azurerm/datafactory/"
  location             = var.location
  resource_group_name  = module.az_resourcegroup.name
  resource_prefix      = module.az_globalvars.resource_prefix
  name                 = "adf"
  tags                 = module.az_globalvars.tags
  vsts_branch_name     = var.adf_vsts_branch_name
  vsts_project_name    = var.adf_vsts_project_name
  vsts_repository_name = var.adf_vsts_repository_name
  vsts_root_folder     = var.adf_vsts_root_folder
  diagnostics_map      = local.diagnostics_map
}
