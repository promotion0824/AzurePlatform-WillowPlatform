/**********************************************************************************************/
# this section creates the resource group for deployment dashboard dev environment
resource "azurerm_resource_group" "rsg-dev" {
  name     = "t3-wil-dev-iot-depdb-aue1-app-rsg"
  location = "australiaeast"
  tags     = local.tags
}

# this section creates the storage account for deployment dashboard dev environment
resource "azurerm_storage_account" "storageaccount" {
  name                      = "wildeviotdepdbaue1iot"
  resource_group_name       = azurerm_resource_group.rsg-dev.name
  location                  = azurerm_resource_group.rsg-dev.location
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  account_kind              = "StorageV2"
  tags                      = local.tags
  enable_https_traffic_only = true
  access_tier               = "Hot"
  is_hns_enabled            = false
}

resource "azurerm_storage_container" "edgedeployments" {
  name                  = "edgedeployments"
  container_access_type = "private"
  storage_account_name  = azurerm_storage_account.storageaccount.name
}

# this section creates the IoT Hub for deployment dashboard dev environment
module "az_iothub" {
  source                                 = "../../../terraform-modules/azurerm/iothub/"
  location                               = azurerm_resource_group.rsg-dev.location
  resource_group_name                    = azurerm_resource_group.rsg-dev.name
  resource_prefix                        = "wil-dev-iot-depdb-aue1-"
  name                                   = "iot"
  tags                                   = local.tags
  sku_name                               = "S1"
  storage_primary_blob_connection_string = azurerm_storage_account.storageaccount.primary_blob_connection_string
  storage_container_name                 = "rawdata"
  encoding                               = "Json"
}

# this section creates the key vault for deployment dashboard dev environment
module "customerKeyvault" {
  source              = "../../../terraform-modules/azurerm/keyvault"
  location            = azurerm_resource_group.rsg-dev.location
  resource_group_name = azurerm_resource_group.rsg-dev.name
  resource_prefix     = "wil-dev-iot-dep-aue1-"
  tags                = local.tags
}

# this section creates the appinsights for this dashboard dev environment
resource "azurerm_application_insights" "appinsights" {
  application_type    = "web"
  location            = var.location
  tags                = local.tags
  retention_in_days   = 30
  sampling_percentage = 100
  disable_ip_masking  = true
  name                = "wil-dev-iot-dep-aue1-ain"
  resource_group_name = azurerm_resource_group.rsg-dev.name
  daily_data_cap_in_gb= 1
}

# this section assigns the required roles for above resources
data "azuread_service_principal" "dashboard" {
  display_name = "edgedeployment-dashboard-dev-pod-id"
}

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault_access_policy" "secretList" {
  key_vault_id = module.customerKeyvault.id
  object_id    = data.azuread_service_principal.dashboard.object_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  secret_permissions = ["get", "list"]
}

data "azuread_group" "IoTGroup" {
  display_name  = "P&E Willow Twin IoT"
}

resource "azurerm_key_vault_access_policy" "IoTServicesPermission" {
  key_vault_id = module.customerKeyvault.id
  object_id    = data.azuread_group.IoTGroup.object_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  secret_permissions = ["get", "list", "set", "delete", "recover", "backup", "restore"]
}

resource "azurerm_role_assignment" "roles_sto_acc_cust_iot_dashboard" {
  scope                = azurerm_storage_account.storageaccount.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_service_principal.dashboard.id
}

resource "azurerm_role_assignment" "roles_iot_hub_cust_iot_dashboard" {
  scope                = module.az_iothub.id
  role_definition_name = "IoT Hub Data Contributor"
  principal_id         = data.azuread_service_principal.dashboard.id
}

resource "azurerm_role_assignment" "roles_reader_iot_dashboard" {
  principal_id = data.azuread_service_principal.dashboard.id
  scope        = azurerm_resource_group.rsg-dev.id
  role_definition_name = "Reader"
}