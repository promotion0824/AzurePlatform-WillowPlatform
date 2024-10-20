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
  resource_prefix = module.az_globalvars.resource_prefix
  name            = "app"
  tier            = module.az_globalvars.tier
  tags            = module.az_globalvars.tags
}

#Azure Storage acount is used by azure function app for:
# - managing triggers and logging function executions
# - storing function reading from eventhub checkpoint
module "az_storageaccount" {
  source              = "../../terraform-modules/azurerm/storageaccount/"
  location            = var.location
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix
  name                = "iot"
  tags                = module.az_globalvars.tags
  create_container    = var.storage_account_create_container
  container_name      = var.storage_account_container_name
  account_tier        = var.storage_account_tier
  replication_type    = var.storage_account_replication_type
}

module "az_functionapp" {
  source                   = "../../terraform-modules/azurerm/functionapp/"
  location                 = var.location
  resource_group_name      = module.az_resourcegroup.name
  resource_prefix          = module.az_globalvars.resource_prefix
  names                    = var.function_app_names
  tags                     = module.az_globalvars.tags
  function_app_version     = var.function_app_version
  storage_account_name     = module.az_storageaccount.name
  app_service_plan_resource_group_name = local.shared_resourcegroup_name
  app_service_plan_name                = local.shared_app_service_appserviceplan_name
  apin_instrumentation_key             = local.shared_applicationinsights_instrumentation_key
  diagnostics_map          = local.diagnostics_map
  deploy_function_app      = var.deploy_function_app
}

#Event hub for events from PI Server/connector to Ingestion Function
module "az_eventhub_sitetoplatform" {
  source              = "../../terraform-modules/azurerm/eventhub/"
  location            = var.location
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix
  sku                 = var.eventhub_sku
  name                = "sit"
  event_hubs = [
    {
      name              = "site-to-platform"
      partitions        = var.eventhub_partition_sitetoplatform
      message_retention = var.eventhub_message_retention
      keys = [
        {
          name   = "connector_send_to_eventhub_key"
          listen = false
          send   = true
        },
        {
          name   = "functionapp_listen_to_eventhub_key"
          listen = true
          send   = false
        }
      ],
      consumers = []
    }
  ]
   network_rules = {
      ip_rules = []
      subnet_ids = []
  }
  tags = module.az_globalvars.tags
}

#Event hub for planned shutdown events from PPMS to PDP (Planned Data Processor)
module "az_eventhub_ppmstoplatform" {
  source              = "../../terraform-modules/azurerm/eventhub/"
  location            = var.location
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix
  sku                 = var.eventhub_sku
  name                = "ptp"
  event_hubs = [
    {
      name              = var.eventhub_name_ppms_to_pdp
      partitions        = var.eventhub_partition_ptp
      message_retention = var.eventhub_message_retention
      keys = [],
      consumers = []
    }
  ]
   network_rules = {
      ip_rules = []
      subnet_ids = []
  }
  tags = module.az_globalvars.tags
}

resource "azurerm_role_assignment" "ptp_eventhub_reader_twin_platform" {
  scope                = module.az_eventhub_ppmstoplatform.hub_ids[var.eventhub_name_ppms_to_pdp]
  role_definition_name = "Azure Event Hubs Data Receiver"
  principal_id         = var.twin_platform_managed_identity_principal_id
}

#Unified event hub to send events from Ingestion Function to ADX
module "az_eventhub_unified" {
  source              = "../../terraform-modules/azurerm/eventhub/"
  location            = var.location
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix
  sku                 = var.eventhub_sku
  name                = "uie"
  event_hubs = [
    {
      name              = "ingestion-to-adx"
      partitions        = var.eventhub_partition_unified
      message_retention = var.eventhub_message_retention
      keys = [],
      consumers = ["adx-cg"]
    }
  ]
   network_rules = {
      ip_rules = []
      subnet_ids = []
  }
  tags = module.az_globalvars.tags
}

#ADX database to store data sent over Unified event hub by the Ingestion Funciton
resource "azurerm_kusto_database" "adx_database" {
  provider            = azurerm.adx
  name                = "${var.long_customer_name}-${module.az_globalvars.env_prefix}"
  resource_group_name = var.adx_cluster_resource_group
  location            = var.location
  cluster_name        = var.adx_cluster_name
  hot_cache_period    = "P90D"
}

#Configure ADX table and mapping from powershell script
resource "null_resource" "configureadx" {
  triggers = {
    version = var.adx_configuration_version
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/../../MiningScripts/"
    command = "PowerShell -file ConfigureADX.ps1 -adxClusterName ${var.adx_cluster_name} -adxDBName ${var.long_customer_name}-${module.az_globalvars.env_prefix} -adxClusterlocation ${var.location} -Verbose"
  }

  depends_on = [
    azurerm_kusto_database.adx_database
  ]
}

#Data connection between Unified event hub and the ADX database
resource "azurerm_kusto_eventhub_data_connection" "eventhub_connection" {
  provider            = azurerm.adx
  name                = "${var.long_customer_name}-${module.az_globalvars.env_prefix}-connection"
  resource_group_name = var.adx_cluster_resource_group
  location            = var.location
  cluster_name        = var.adx_cluster_name
  database_name       = "${var.long_customer_name}-${module.az_globalvars.env_prefix}"

  eventhub_id         = module.az_eventhub_unified.hub_ids["ingestion-to-adx"]
  consumer_group      = "adx-cg"

  table_name          = "Telemetry"
  mapping_rule_name   = "TelemetryMapping"
  data_format         = "MULTIJSON"

  depends_on = [
    null_resource.configureadx
  ]
}

resource "azurerm_monitor_action_group" "mining_actiongroup" {
  provider            = azurerm.adx
  name                = "${var.customer_prefix}-${module.az_globalvars.env_prefix}-actiongroup"
  resource_group_name = var.adx_cluster_resource_group
  short_name          = "${var.customer_prefix}-${module.az_globalvars.env_prefix}"

  email_receiver {
    name                    = "sendtoteams"
    email_address           = var.teams_alert_email
    use_common_alert_schema = true
  }
}

data "azurerm_kusto_cluster" "sharedcluster" {
  name                = var.adx_cluster_name
  resource_group_name = var.adx_cluster_resource_group
  provider            = azurerm.adx
}

resource "azurerm_monitor_metric_alert" "noingestion_metricalert" {
  provider            = azurerm.adx
  name                = "${var.customer_prefix}_${module.az_globalvars.env_prefix}_noingestion_metricalert"
  resource_group_name = var.adx_cluster_resource_group
  scopes              = [data.azurerm_kusto_cluster.sharedcluster.id]
  description         = "Action will be triggered when events received is less than threshold."
  frequency           = "PT5M"
  window_size         = "PT15M"
  severity            = 0 //critical

  criteria {
    metric_namespace = "Microsoft.Kusto/clusters"
    metric_name      = "EventsReceived"
    aggregation      = "Total"
    operator         = "LessThanOrEqual"
    threshold        = 0

    dimension {
      name     = "ComponentName"
      operator = "Include"
      values   = ["${var.long_customer_name}-${module.az_globalvars.env_prefix}-connection"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.mining_actiongroup.id
  }

  depends_on = [
    azurerm_kusto_eventhub_data_connection.eventhub_connection,
    azurerm_monitor_action_group.mining_actiongroup
  ]
}

# Storage account for historical data import
module "az_storageaccount_import" {
  source              = "../../terraform-modules/azurerm/storageaccount/"
  location            = var.location
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix
  name                = "imp"
  tags                = module.az_globalvars.tags
  create_container    = true
  container_name      = "data-import"
  account_tier        = var.storage_account_tier
  replication_type    = var.storage_account_replication_type
}