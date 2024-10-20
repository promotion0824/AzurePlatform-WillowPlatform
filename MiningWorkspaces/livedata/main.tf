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

module "az_functionapp" {
  source                               = "../../terraform-modules/azurerm/functionapp/"
  location                             = var.location
  resource_group_name                  = module.az_resourcegroup.name
  resource_prefix                      = module.az_globalvars.resource_prefix
  names                                = var.function_app_names
  app_service_plan_resource_group_name = local.shared_resourcegroup_name
  app_service_plan_name                = local.shared_app_service_appserviceplan_name
  tags                                 = module.az_globalvars.tags
  function_app_version                 = var.function_app_version
  storage_account_name                 = module.az_storageaccount.name
  apin_instrumentation_key             = local.shared_applicationinsights_instrumentation_key
  diagnostics_map                      = local.diagnostics_map
  deploy_function_app                  = var.deploy_function_app
}

module "az_appservice" {
  source                               = "../../terraform-modules/azurerm/appservice_linux/"
  location                             = var.location
  resource_group_name                  = module.az_resourcegroup.name
  resource_prefix                      = module.az_globalvars.resource_prefix
  names                                = var.web_app_names
  app_service_plan_resource_group_name = local.shared_resourcegroup_name
  app_service_plan_name                = local.shared_app_service_appserviceplan_name
  tags                                 = module.az_globalvars.tags
  apin_instrumentation_key             = local.shared_applicationinsights_instrumentation_key
  key_vault_name                       = local.shared_keyvault_name
  diagnostics_map                      = local.diagnostics_map
}

resource "azurerm_application_insights_web_test" "lda_app_service_availability_test" {
  for_each                = toset(var.web_app_names)
  name                    = "${each.key}-availability"
  location                = var.location
  resource_group_name     = local.shared_resourcegroup_name
  application_insights_id = local.shared_applicationinsights_id
  kind                    = "ping"
  frequency               = 300
  timeout                 = 60
  enabled                 = true
  geo_locations           = ["emea-au-syd-edge", "apac-sg-sin-azr", "us-ca-sjc-azr", "emea-se-sto-edge"]
  description             = "Health Checks"

  configuration = <<XML
<WebTest Name="${each.key}test" Enabled="True" CssProjectStructure="" CssIteration="" Timeout="0" WorkItemIds="" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010" Description="" CredentialUserName="" CredentialPassword="" PreAuthenticate="True" Proxy="default" StopOnError="False" RecordedResultFile="" ResultsLocale="">
  <Items>
    <Request Method="GET" Version="1.1" Url="https://${module.az_globalvars.resource_prefix}${each.key}.azurewebsites.net/healthcheck" ThinkTime="0" Timeout="300" ParseDependentRequests="True" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" ExpectedResponseUrl="" ReportingName="" IgnoreHttpStatusCode="False" />
  </Items>
</WebTest>
XML
}

