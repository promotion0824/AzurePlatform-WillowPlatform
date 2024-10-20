/**********************************************************************************************/
# this section creates the resource groups for general deployment dashboard resources

resource "azurerm_resource_group" "rsg-dev" {
  name     = "deployment-dashboard-dev-rsg"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "rsg-prd" {
  name     = "deployment-dashboard-prd-rsg"
  location = var.location
  tags     = local.tags
}

locals {
  groupnames = [
    "P&E Willow Twin IoT"
  ]
}
# ##############################
# this section assigns the contributor role for the defined security groups for dev
# for prd resource group, contributor access will be via PIM requests

data "azuread_group" "groups" {
  count = length(local.groupnames)
  display_name  = local.groupnames[count.index] 
}

resource "azurerm_role_assignment" "roles_contributor_dev" {
  scope                = azurerm_resource_group.rsg-dev.id
  role_definition_name = "Contributor"

  for_each = {
    for i, v in data.azuread_group.groups : i => v
  }
  principal_id = each.value.object_id
}

# Storage Table Data Contributor access for groups in dev resource group
resource "azurerm_role_assignment" "roles_contributor_dev_table" {
  scope                = azurerm_resource_group.rsg-dev.id
  role_definition_name = "Storage Table Data Contributor"

  for_each = {
    for i, v in data.azuread_group.groups : i => v
  }
  principal_id = each.value.object_id
}

/**********************************************************************************************/
# this section creates the user assigned managed identities for each deployment dashboard service

variable "managed_identity_names_dev" {
  type = list(any)
  default = [
    "edgedeployment-dashboard-dev-pod-id"
  ]
}

resource "azurerm_user_assigned_identity" "user_assigned_identities_dev" {
  resource_group_name = azurerm_resource_group.rsg-dev.name
  location            = azurerm_resource_group.rsg-dev.location
  tags                = local.tags

  for_each = toset(var.managed_identity_names_dev)
  name     = each.value
}

/**********************************************************************************************/

variable "managed_identity_names_prd" {
  type = list(any)
  default = [
    "edgedeployment-dashboard-prd-pod-id"
  ]
}

resource "azurerm_user_assigned_identity" "user_assigned_identities_prd" {
  resource_group_name = azurerm_resource_group.rsg-prd.name
  location            = azurerm_resource_group.rsg-prd.location
  tags                = local.tags

  for_each = toset(var.managed_identity_names_prd)
  name     = each.value
}

/**********************************************************************************************/
# this section creates Azure Service Bus

resource "azurerm_servicebus_namespace" "edgedashboardnamespacedev" {
  name                = "edgedeployment-dashboard-dev-sbns"
  resource_group_name = azurerm_resource_group.rsg-dev.name
  location            = azurerm_resource_group.rsg-prd.location
  tags                = local.tags
  sku                 = "Standard" 
}

resource "azurerm_servicebus_namespace" "edgedashboardnamespaceprd" {
  name                = "edgedeployment-dashboard-prd-sbns"
  resource_group_name = azurerm_resource_group.rsg-prd.name
  location            = azurerm_resource_group.rsg-prd.location
  tags                = local.tags
  sku                 = "Standard" 
}

/**********************************************************************************************/

# Create application insights resource for each namespace

data "azurerm_log_analytics_workspace" "logworkspace" {
  name                = "nonprodplatformshared-aue-log"
  resource_group_name = "nonprod-platformshared"
}

resource "azurerm_application_insights" "appinsights" {
  application_type    = "web"
  location            = var.location
  tags                = local.tags
  retention_in_days   = 30
  sampling_percentage = 100
  disable_ip_masking  = true
  workspace_id        = data.azurerm_log_analytics_workspace.logworkspace.id # dev services cluster only runs in one region

  for_each = { 
    for i, v in local.namespaces : i => v 
  }
  name                  = "deployment-dashboard-${each.value.env}-ain"
  resource_group_name   = each.value.rsg
  daily_data_cap_in_gb  = each.value.env == "prd" ? null : 1
}

/**********************************************************************************************/

# Create storage account and container for each namespace and provide access to managed identities

resource "azurerm_storage_account" "storageaccount" {
  location                  = var.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  account_kind              = "StorageV2"
  tags                      = local.tags
  enable_https_traffic_only = true
  access_tier               = "Hot"
  is_hns_enabled            = false

  for_each = {
    for i, v in local.namespaces : i => v
  }
  name                     = "edgedeployment${each.value.env}sto"
  resource_group_name      = each.value.rsg
}

resource "azurerm_storage_container" "edgedeployments" {
  name                  = "edgedeployments"
  container_access_type = "private"

  for_each = {
    for i, v in local.namespaces : i => v
  }
  storage_account_name  = "edgedeployment${each.value.env}sto"
  depends_on = [
    azurerm_storage_account.storageaccount
  ]
}

/**********************************************************************************************/
# this section defines the namespaces and required mappings

data "azurerm_user_assigned_identity" "keda_pod_identity" {
  name                = "keda-pod-id16a91be1"
  resource_group_name = "internal-devservices"
}

data "azurerm_user_assigned_identity" "dashboard_dev_identity" {
  name                = "edgedeployment-dashboard-dev-pod-id"
  resource_group_name = azurerm_resource_group.rsg-dev.name
}

data "azurerm_user_assigned_identity" "dashboard_prd_identity" {
  name                = "edgedeployment-dashboard-prd-pod-id"
  resource_group_name = azurerm_resource_group.rsg-prd.name
}

locals {
  namespaces = [
    {
      env     = "dev"
      rsg     = "deployment-dashboard-dev-rsg"
      id      = data.azurerm_user_assigned_identity.dashboard_dev_identity.principal_id
      sbus_id = azurerm_servicebus_namespace.edgedashboardnamespacedev.id
      pod_id  = data.azurerm_user_assigned_identity.keda_pod_identity.principal_id
      resource_id = data.azurerm_user_assigned_identity.dashboard_dev_identity.id
    },
    {
      env     = "prd"
      rsg     = "deployment-dashboard-prd-rsg"
      id      = data.azurerm_user_assigned_identity.dashboard_prd_identity.principal_id
      sbus_id = azurerm_servicebus_namespace.edgedashboardnamespaceprd.id
      pod_id  = data.azurerm_user_assigned_identity.keda_pod_identity.principal_id
      resource_id = data.azurerm_user_assigned_identity.dashboard_prd_identity.id
    }
  ]
}

# ##############################
# this sub-section assigns the reader role to the KEDA managed identity
# it also assigns service bus send and receive roles for the deployment dashboard identity 

# reader access for the KEDA managed identity
resource "azurerm_role_assignment" "roles_sbns_reader_keda_dev" {
  role_definition_name = "Reader"
  for_each = {
    for i, v in local.namespaces : i => v
  }
  scope         = each.value.sbus_id
  principal_id  = each.value.pod_id
}

# service bus owner access for dashboard identities
resource "azurerm_role_assignment" "roles_sbns_receiver_dashboard" {
  role_definition_name = "Azure Service Bus Data Owner"
  for_each = {
    for i, v in local.namespaces : i => v
  }
  scope         = each.value.sbus_id
  principal_id  = each.value.id
}

# service bus send access for IoT Team members in DEV
resource "azurerm_role_assignment" "roles_sbns_sender_dashboard_dev_team" {
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id = data.azuread_group.groups[0].id
  for_each = {
    for i, v in local.namespaces : i => v if v.env == "dev"
  }
  scope         = each.value.sbus_id
}

# deployment dashboard needs both Storage Table and Storage Blob contributor access
resource "azurerm_role_assignment" "roles_sto_acc_region_lda_dashboard" {
  role_definition_name = "Storage Blob Data Contributor"

  for_each = {
    for i, v in azurerm_storage_account.storageaccount : i => v
  }

  principal_id = length(regexall("prd", each.value.name)) > 0 ? data.azurerm_user_assigned_identity.dashboard_prd_identity.principal_id : data.azurerm_user_assigned_identity.dashboard_dev_identity.principal_id 
  scope = each.value.id
}

resource "azurerm_role_assignment" "roles_sto_acc_region_lda_dashboard_table" {
  role_definition_name = "Storage Table Data Contributor"

  for_each = {
    for i, v in azurerm_storage_account.storageaccount : i => v
  }

  principal_id = length(regexall("prd", each.value.name)) > 0 ? data.azurerm_user_assigned_identity.dashboard_prd_identity.principal_id : data.azurerm_user_assigned_identity.dashboard_dev_identity.principal_id
  scope = each.value.id
}

# Add Service Bus Sender role to each of the forwarding function apps
# We need this for DEV sbns for initial development but eventually the deployment dashboard will be running in PRD

locals {
  functionAppIds = split(",", var.forwarding_function_system_identity_list)
}

resource "azurerm_role_assignment" "roles_sbns_sender_forwarding_func_dev" {
  role_definition_name = "Azure Service Bus Data Sender"
  # These functions reside in a different subscription and there is no easy way to get them dynamically within TF
  scope                = azurerm_servicebus_namespace.edgedashboardnamespacedev.id
  for_each = {
    for i, v in local.functionAppIds : i => v
  }
  principal_id         = each.value
}

resource "azurerm_role_assignment" "roles_sbns_sender_forwarding_func_prd" {
  role_definition_name = "Azure Service Bus Data Sender"
  # These functions reside in a different subscription and there is no easy way to get them dynamically within TF
  scope                = azurerm_servicebus_namespace.edgedashboardnamespaceprd.id
  for_each = {
    for i, v in local.functionAppIds : i => v
  }
  principal_id         = each.value
}

# ##############################
# This sub-section creates Azure Serverless sql database for deployment dashboard in both environments
# ##############################
 data "azurerm_client_config" "current" {}
data "azuread_group" "SQLSecurityGroupNonProd" {
  display_name = "IoT-SqlAdmin-Nonprod"
}
data "azuread_group" "SQLSecurityGroupProd" {
  display_name = "IoT-SqlAdmin-Prod"
}

resource "azurerm_mssql_server" "sqlserver" {
  tags                         = local.tags
  location                     = var.location
  version                      = "12.0"
  for_each = {
    for i, v in local.namespaces : i => v
  }
  name                         = length(regexall("prd", each.value.env)) > 0 ? "deploymentdashboard-sqlserver-prd" : "deploymentdashboard-sqlserver-dev"
  azuread_administrator {
    login_username = length(regexall("prd", each.value.env)) > 0 ? data.azuread_group.SQLSecurityGroupProd.display_name : data.azuread_group.SQLSecurityGroupNonProd.display_name
    object_id      = length(regexall("prd", each.value.env)) > 0 ? data.azuread_group.SQLSecurityGroupProd.id : data.azuread_group.SQLSecurityGroupNonProd.id
    azuread_authentication_only = true
  }
  identity {
    type = "UserAssigned"
    identity_ids = [
      each.value.resource_id
    ]
  }
  primary_user_assigned_identity_id = each.value.resource_id
  resource_group_name          = each.value.rsg
}

resource "azurerm_mssql_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
  for_each = {
    for i, v in azurerm_mssql_server.sqlserver : i => v
  }
  server_id        = azurerm_mssql_server.sqlserver[each.key].id
  
}

# Separate DEV and PRD databases as they require different variable control 
resource "azurerm_mssql_database" "DeploymentDashboardDatabaseDev" {
  name      = "DeploymentDb"
  sku_name  = var.sql_db_sku_dev
  min_capacity = var.sql_db_min_capacity_dev
  max_size_gb = var.sql_db_max_size_gb_dev
  auto_pause_delay_in_minutes = var.sql_db_pause_delay_minutes_dev
  zone_redundant = false
  tags      = local.tags
  for_each = {
        for i, v in azurerm_mssql_server.sqlserver : i => v if length(regexall("dev", v.name)) > 0
  }
  server_id = azurerm_mssql_server.sqlserver[each.key].id
}

resource "azurerm_mssql_database" "DeploymentDashboardDatabasePrd" {
  name      = "DeploymentDb"
  sku_name  = var.sql_db_sku_prd
  min_capacity = var.sql_db_min_capacity_prd
  max_size_gb = var.sql_db_max_size_gb_prd
  auto_pause_delay_in_minutes = var.sql_db_pause_delay_minutes_prd
  zone_redundant = false
  tags      = local.tags
  for_each = {
    for i, v in azurerm_mssql_server.sqlserver : i => v if length(regexall("prd", v.name)) > 0
  }
  server_id = azurerm_mssql_server.sqlserver[each.key].id
}

# ##############################
# Create deploy-module queue in PRD environment
# ##############################
resource "azurerm_servicebus_queue" "DeployModulePrdQueue" {
  name                  = "deploy-module"
  namespace_id          = azurerm_servicebus_namespace.edgedashboardnamespaceprd.id
  max_size_in_megabytes = 1024
}