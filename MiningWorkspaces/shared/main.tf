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

#Existing Storage account t2-wil-ncp-lda-shr-aue1-mgt-rsg\wilncpldashraue1sto
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

resource "azurerm_storage_container" "container_dataprotectionkeys" {
  name                  = "dataprotectionkeys"
  storage_account_name  = module.az_storageaccount.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "container_portalxl" {
  name                  = "portalxl"
  storage_account_name  = module.az_storageaccount.name
  container_access_type = "private"
}

#Existing Key Vault t2-wil-ncp-lda-shr-aue1-mgt-rsg\wil-ncp-lda-shr-aue1-kvl
module "az_keyvault" {
  source              = "../../terraform-modules/azurerm/keyvault/"
  location            = var.location
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix_shared
  name                = "kvl"
  tags                = module.az_globalvars.tags
  sku_name            = var.key_vault_sku_name
  access_policies = [{
    description = "Front Door needs access to keyvault"
    default = [{
      object_ids             = ["ad0e1c7e-6d38-4ba4-9efd-0bc77ba9f037"]
      key_permissions         = []
      secret_permissions      = ["Get"]
      certificate_permissions = ["Get"]
      storage_permissions     = []
    }
    ]
  }]
}

#------------------------------------------------------------------------------------
# Begin Mining changes
# Define shared Azure Resources to consolidate for Mining
# Note variables defined in ./variables.tf and copied from existing workspaces
#------------------------------------------------------------------------------------

#Create new shared windows app service plan based on Workspaces/customers/main.tf
module "az_appserviceplan" {
  source              = "../../terraform-modules/azurerm/appserviceplan/"
  location            = var.location
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix_shared
  name                = "asp"
  tags                = module.az_globalvars.tags
  notification_emails = module.az_globalvars.notification_emails
  sku_tier            = var.app_service_plan_sku_tier
  sku_size            = var.app_service_plan_sku_size
  enable_autoscale    = var.app_service_enable_autoscale
}

#Create new SQL Azure Server based on Workspaces/customers/main.tf
module "az_sqlserver" {
  source                 = "../../terraform-modules/azurerm/sqlserver/"
  location               = var.location
  resource_group_name    = module.az_resourcegroup.name
  resource_prefix        = module.az_globalvars.resource_prefix_shared
  tags                   = module.az_globalvars.tags
  notification_emails    = module.az_globalvars.notification_emails
  administrator_password = var.sql_administrator_password
  aad_admin_login_name   = var.sql_aad_admin_login_name
  #Note PoC has NcpDB but cant see where created in terraform
  database_names                            = ["DirectoryCoreDB", "SiteCoreDB", "WorkflowCoreDB", "DigitalTwinDB"]
  database_edition                          = var.sql_database_edition
  database_requested_service_objective_name = var.sql_database_requested_service_objective_name
  diagnostics_map = map(
    "sa_id", module.az_storageaccount_diag.id,
    "la_id", module.az_loganalytics_diag.resource_id,
    "rg_name", module.az_resourcegroup.name,
    "sa_name", module.az_storageaccount_diag.name,
    "la_name", module.az_loganalytics_diag.name,
  )
}

#Configure Azure SQL
resource "null_resource" "configureazuresql" {
  triggers = {
    version = var.sql_configuration_version
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/../../MiningScripts/"
    command = "PowerShell -file ConfigureAzureSQL.ps1 -sqlServerPrefix ${module.az_globalvars.resource_prefix_shared} -appServicePrefix ${module.az_globalvars.company_prefix}-${module.az_globalvars.env_prefix}-${var.project_prefix} -appServiceSuffix ${module.az_globalvars.location_with_zone_prefix} -twinPlatformManagedIdentityPrincipalId ${var.twinPlatformManagedIdentityPrincipalId} -authApiManagedIdentityPrincipalId ${var.authApiManagedIdentityPrincipalId} -Verbose"
  }

  depends_on = [
    module.az_sqlserver
  ]
}

#Create SQL Azure Server alerts based on Workspaces/applications/main.tf
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

#shared app insights
module "az_applicationinsights" {
  source                          = "../../terraform-modules/azurerm/applicationinsights/"
  location                        = var.location
  resource_group_name             = module.az_resourcegroup.name
  resource_prefix                 = module.az_globalvars.resource_prefix_shared
  name                            = "ain"
  tags                            = module.az_globalvars.tags
  daily_data_cap_in_gb            = var.app_insights_daily_data_cap_in_gb
}

resource "azurerm_application_insights_web_test" "mining_api_availability_test" {
  name                    = "mining-api-availability"
  location                = var.location
  resource_group_name     = module.az_resourcegroup.name
  application_insights_id = module.az_applicationinsights.id
  kind                    = "ping"
  frequency               = 300
  timeout                 = 60
  enabled                 = true
  retry_enabled           = true
  geo_locations           = ["emea-au-syd-edge", "apac-sg-sin-azr", "us-ca-sjc-azr", "emea-se-sto-edge"]
  description             = "Mining API Health Check"

  configuration = <<XML
<WebTest Name="MiningApiTest" Enabled="True" CssProjectStructure="" CssIteration="" Timeout="0" WorkItemIds="" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010" Description="" CredentialUserName="" CredentialPassword="" PreAuthenticate="True" Proxy="default" StopOnError="False" RecordedResultFile="" ResultsLocale="">
  <Items>
    <Request Method="GET" Version="1.1" Url="https://${module.az_globalvars.company_prefix}-${module.az_globalvars.env_prefix}-${var.project_prefix}-shr-glb-command.azurefd.net/au/api/mining/health" ThinkTime="0" Timeout="300" ParseDependentRequests="True" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" ExpectedResponseUrl="" ReportingName="" IgnoreHttpStatusCode="False" />
  </Items>
</WebTest>
XML
}
#------------------------------------------------------------------------------------
# End Mining Changes
#------------------------------------------------------------------------------------