## data sources
data "azurerm_subscription" "subscription" {}

data "azurerm_kusto_cluster" "sharedcluster" {
  name                = var.adx_cluster_name
  resource_group_name = var.adx_cluster_resource_group
  provider = azurerm.adx
}

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

# Get existing resource groups
data "azurerm_resource_group" "customer_rsg" {
  name = local.customer-lda-rsg
}

# Get application insights
data "azurerm_application_insights" "appinsights" {
  name                = "${local.customer-lda-prefix}-ain"
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
}

# Get app service plan
data "azurerm_app_service_plan" "appserviceplan" {
  name                = "${local.customer-lda-prefix}-asp"
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
}

# Get storage account
data "azurerm_storage_account" "storageaccount" {
  name                = replace("${local.customer-lda-prefix}iot", "-", "")
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
}

# Get saj eventhub namespace
data "azurerm_eventhub_namespace" "saj" {
  name                = "${local.customer-lda-prefix}-saj"
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
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

module "az_functionapp" {
  source                   = "../../terraform-modules/azurerm/functionapp/"
  location                 = var.location
  resource_group_name      = data.azurerm_resource_group.customer_rsg.name
  resource_prefix          = module.az_globalvars.resource_prefix
  names                    = var.function_app_names
  tags                     = module.az_globalvars.tags
  app_service_plan_name    = data.azurerm_app_service_plan.appserviceplan.name
  storage_account_name     = data.azurerm_storage_account.storageaccount.name
  apin_instrumentation_key = data.azurerm_application_insights.appinsights.instrumentation_key
  diagnostics_map          = local.diagnostics_map
  retention_in_days        = 0
  deploy_function_app      = var.deploy_function_app
}

resource "azurerm_iothub_consumer_group" "iotadaptor" {
  eventhub_endpoint_name = "events"
  iothub_name            = "${module.az_globalvars.resource_prefix}iot"
  name                   = "iotadaptor"
  resource_group_name    = data.azurerm_resource_group.customer_rsg.name
}

resource "azurerm_eventhub_consumer_group" "external-events-adaptor" {
  count               = var.skip_external_events == true ? 0 : 1
  eventhub_name       = "input-to-lda"
  name                = "external-events-adaptor"
  namespace_name      = "${module.az_globalvars.resource_prefix}saj"
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
}

# Unified ingest event hub to send canonical events to ADX
module "az_unified_eventhub" {
  source = "../../terraform-modules/azurerm/eventhub"
  location = var.location
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
  resource_prefix = module.az_globalvars.resource_prefix
  name = "uie"
  event_hubs = [
    {
      name = "ingestion-to-adx"
      partitions = 32
      message_retention = var.eventhub_message_retention
      keys = []
      consumers = ["adx-cg", "data-quality-cg"]
    },
    {
      name = "ingestion-to-cleaned-telemetry"
      partitions = 32
      message_retention = var.eventhub_message_retention
      keys = []
      consumers = ["adx-cg"]
    },
    {
      name = "connector-state-to-adx"
      partitions = 2
      message_retention = var.eventhub_message_retention
      keys = []
      consumers = ["adx-cg"]
    }
  ]
  network_rules = {
    ip_rules = []
    subnet_ids = []
  }
  capture = {
    enabled = var.eventhub_capture_enable
    encoding = "Avro"
    interval_in_seconds = 300
    size_limit_in_bytes = 314572800
    blob_container_name = "canonical-event-ingress"
    storage_account_id = data.azurerm_storage_account.storageaccount.id
  }
  tags = module.az_globalvars.tags
  diagnostics_map = local.diagnostics_map
  retention_in_days = 0
}

# ADX Database for customer
resource "azurerm_kusto_database" "adx_database" {
  count = var.create_adx_database == true ? 1 : 0
  provider = azurerm.adx
  cluster_name = var.adx_cluster_name
  location = var.adx_cluster_location
  name = var.adx_database_name
  resource_group_name = var.adx_cluster_resource_group
  hot_cache_period = "P90D"
}

# Configure ADX Telemetry table permissions and ingestion mapping via script
resource "null_resource" "configureadx" {
  triggers = {
    version = var.adx_configuration_version
  }
  provisioner "local-exec" {
    working_dir = "${path.module}/Scripts"
    command = "PowerShell -file ConfigureTelemetryTables.ps1 -adxClusterName ${var.adx_cluster_name} -adxDBName ${var.adx_database_name} -adxTableName Telemetry -adxClusterlocation ${var.adx_cluster_location} -Verbose"
  }

  depends_on = [
    azurerm_kusto_database.adx_database
  ]
}

# Configure ADX Telemetry table permissions and ingestion mapping via script
resource "null_resource" "configureadx_cleanedTelemetry" {
  triggers = {
    version = var.adx_configuration_version
  }
  provisioner "local-exec" {
    working_dir = "${path.module}/Scripts"
    command = "PowerShell -file ConfigureTelemetryTables.ps1 -adxClusterName ${var.adx_cluster_name} -adxDBName ${var.adx_database_name} -adxTableName CleanedTelemetry -adxClusterlocation ${var.adx_cluster_location} -Verbose"
  }

  depends_on = [
    azurerm_kusto_database.adx_database
  ]
}

# Configure ADX ConnectorState table permissions and ingestion mapping via script
resource "null_resource" "configureConnectorState" {
  triggers = {
    version = var.adx_configuration_version
  }
  provisioner "local-exec" {
    working_dir = "${path.module}/Scripts"
    command = "PowerShell -file ConnectorState.ps1 -adxClusterName ${var.adx_cluster_name} -adxDBName ${var.adx_database_name} -adxClusterlocation ${var.adx_cluster_location} -Verbose"
  }

  depends_on = [
    azurerm_kusto_database.adx_database
  ]
}

#Data connection between Unified event hub and the ADX database
resource "azurerm_kusto_eventhub_data_connection" "eventhub_connection" {
  count               = var.skip_telemetry_data_connection == true ? 0 : 1
  provider            = azurerm.adx
  name                = "${var.customer_prefix}-${module.az_globalvars.env_prefix}-connection"
  resource_group_name = var.adx_cluster_resource_group
  location            = var.adx_cluster_location
  cluster_name        = var.adx_cluster_name
  database_name       = var.adx_database_name

  eventhub_id         = module.az_unified_eventhub.hub_ids["ingestion-to-adx"]
  consumer_group      = "adx-cg"

  table_name          = "Telemetry"
  mapping_rule_name   = "TelemetryMapping"
  data_format         = "MULTIJSON"

  depends_on = [
    null_resource.configureadx,
    module.az_unified_eventhub
  ]
}

#Data connection between cleaned telemetry event hub and the ADX database
resource "azurerm_kusto_eventhub_data_connection" "eventhub_connection_cleaned_telemetry" {
  provider            = azurerm.adx
  name                = "${var.customer_prefix}-${module.az_globalvars.env_prefix}-cleaned-telemetry-connection"
  resource_group_name = var.adx_cluster_resource_group
  location            = var.adx_cluster_location
  cluster_name        = var.adx_cluster_name
  database_name       = var.adx_database_name

  eventhub_id         = module.az_unified_eventhub.hub_ids["ingestion-to-cleaned-telemetry"]
  consumer_group      = "adx-cg"

  table_name          = "CleanedTelemetry"
  mapping_rule_name   = "CleanedTelemetryMapping"
  data_format         = "MULTIJSON"

  depends_on = [
    null_resource.configureadx,
    module.az_unified_eventhub
  ]
}

#Data connection between Connector state event hub and the ADX database
resource "azurerm_kusto_eventhub_data_connection" "connector_state_eventhub_connection" {
  provider            = azurerm.adx
  name                = "${var.customer_prefix}-${module.az_globalvars.env_prefix}-connector-state-connection"
  resource_group_name = var.adx_cluster_resource_group
  location            = var.adx_cluster_location
  cluster_name        = var.adx_cluster_name
  database_name       = var.adx_database_name

  eventhub_id         = module.az_unified_eventhub.hub_ids["connector-state-to-adx"]
  consumer_group      = "adx-cg"

  table_name          = "ConnectorState"
  mapping_rule_name   = "ConnectorStateMapping"
  data_format         = "MULTIJSON"

  depends_on = [
    null_resource.configureadx,
    module.az_unified_eventhub
  ]
}

resource "azurerm_role_assignment" "adx_eventhub_datareceiver_role" {
  scope                = module.az_unified_eventhub.namespace_id
  principal_id         = var.adx_principal_id
  role_definition_name = "Azure Event Hubs Data Receiver"

    depends_on = [
    null_resource.configureadx,
    module.az_unified_eventhub
  ]
}