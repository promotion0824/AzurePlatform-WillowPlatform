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

module "az_resourcegroup" {
  source          = "../../terraform-modules/azurerm/resourcegroup/"
  location        = var.location
  resource_prefix = module.az_globalvars.resource_prefix_global
  name            = "mgt"
  tier            = module.az_globalvars.tier
  tags            = module.az_globalvars.tags
}

module "az_frontdoor_admin" {
  source                           = "../../terraform-modules/azurerm/frontdoor/"
  location                         = var.location
  resource_group_name              = module.az_resourcegroup.name
  resource_prefix                  = module.az_globalvars.resource_prefix_global
  name                             = "admin"
  dns_name                         = var.frontdoor_dns_name
  enable_custom_domain             = false
  keyvault_certificate_secret_name = var.frontdoor_keyvault_certificate_secret_name
  probe_interval_in_seconds        = var.frontdoor_probe_interval_in_seconds
  backend_pools                    = local.backendpools_admin
  routing_rules                    = local.routingrules_admin
  tags                             = module.az_globalvars.tags
  diagnostics_map                  = local.diagnostics_map
  diagnostics_keyvault_name        = local.diagnostics_keyvault_name
}

module "az_frontdoor_api" {
  source                           = "../../terraform-modules/azurerm/frontdoor/"
  location                         = var.location
  resource_group_name              = module.az_resourcegroup.name
  resource_prefix                  = module.az_globalvars.resource_prefix_global
  name                             = "api"
  dns_name                         = var.frontdoor_dns_name
  enable_custom_domain             = true
  keyvault_certificate_secret_name = var.frontdoor_keyvault_certificate_secret_name
  probe_interval_in_seconds        = var.frontdoor_probe_interval_in_seconds
  backend_pools                    = local.backendpools_api
  routing_rules                    = local.routingrules_api
  tags                             = module.az_globalvars.tags
  diagnostics_map                  = local.diagnostics_map
  diagnostics_keyvault_name        = local.diagnostics_keyvault_name
}

module "az_frontdoor_command" {
  source                           = "../../terraform-modules/azurerm/frontdoor/"
  location                         = var.location
  resource_group_name              = module.az_resourcegroup.name
  resource_prefix                  = module.az_globalvars.resource_prefix_global
  name                             = "command"
  dns_name                         = var.frontdoor_dns_name
  enable_custom_domain             = true
  keyvault_certificate_secret_name = var.frontdoor_keyvault_certificate_secret_name
  probe_interval_in_seconds        = var.frontdoor_probe_interval_in_seconds
  backend_pools                    = local.backendpools_command
  routing_rules                    = local.routingrules_command
  tags                             = module.az_globalvars.tags
  diagnostics_map                  = local.diagnostics_map
  diagnostics_keyvault_name        = local.diagnostics_keyvault_name
}

module "az_frontdoor_mobile" {
  source                           = "../../terraform-modules/azurerm/frontdoor/"
  location                         = var.location
  resource_group_name              = module.az_resourcegroup.name
  resource_prefix                  = module.az_globalvars.resource_prefix_global
  name                             = "command-mobile"
  dns_name                         = var.frontdoor_dns_name
  enable_custom_domain             = true
  keyvault_certificate_secret_name = var.frontdoor_keyvault_certificate_secret_name
  probe_interval_in_seconds        = var.frontdoor_probe_interval_in_seconds
  backend_pools                    = local.backendpools_mobile
  routing_rules                    = local.routingrules_mobile
  tags                             = module.az_globalvars.tags
  diagnostics_map                  = local.diagnostics_map
  diagnostics_keyvault_name        = local.diagnostics_keyvault_name
}