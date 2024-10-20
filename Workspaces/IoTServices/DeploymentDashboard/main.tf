/**********************************************************************************************/
data "azurerm_client_config" "current" {}

# create the customer specific keyvault for iot services stuff
module "customerKeyvault" {
  count               = var.customer_prefix != "" ? 1 : 0
  source              = "../../../terraform-modules/azurerm/keyvault"
  location            = var.location
  resource_group_name = local.customer-lda-rsg
  resource_prefix     = "${local.customer-iot-prefix-limited}-"
  tags                = local.tags
}

data "azuread_group" "keyvaultAdminGroup" {
  display_name = "Azure-Platform-PRD-KV-Admin"
}

# For PRD region, assign FULL permissions to the KVL admin group Azure-Platform-PRD-KV-Admin
resource "azurerm_key_vault_access_policy" "keyvaultAdmin" {
  count           = (local.is_customer_release && local.env-prefix == "prd") ? 1 : 0
  key_vault_id    = module.customerKeyvault[0].id
  object_id       = data.azuread_group.keyvaultAdminGroup.object_id
  tenant_id       = data.azurerm_client_config.current.tenant_id
  key_permissions = [
    "get",
    "create",
    "delete",
    "list",
    "update",
    "import",
    "backup",
    "restore",
    "recover",
    "encrypt",
    "decrypt",
    "unwrapkey",
    "wrapkey",
    "verify",
    "sign"
  ]
  secret_permissions = [
    "get",
    "list",
    "set",
    "delete",
    "backup",
    "restore",
    "recover"
  ]
  certificate_permissions = [
    "get",
    "list",
    "delete",
    "create",
    "import",
    "update",
    "managecontacts",
    "manageissuers",
    "getissuers",
    "listissuers",
    "setissuers",
    "deleteissuers",
    "backup",
    "restore",
    "recover"
  ]
}

/**********************************************************************************************/
# this section assigns access roles for the new managed identities to various required resources.
# the managed identities are assumed to exist.

# (can't use 'azuread_service_principals' data source because we are tied to an older version of azuread.)

data "azuread_service_principal" "dashboard" {
  display_name = "edgedeployment-dashboard-${var.env_id_mapping[local.env-prefix]}-pod-id"
}

##############################
# this sub-section assigns the read access role to the deployment dashboard managed
# identities for the shared region keyvault. not applicable for customer releases.

# the existing shared region lda keyvault [eg. wil-dev-lda-aue1-kvl]
data "azurerm_key_vault" "kvl_region_lda" {
  name                = "${local.region-lda-prefix}-kvl"
  resource_group_name = local.region-lda-rsg
}

# dashboard
resource "azurerm_key_vault_access_policy" "secretListRegional" {
  count              = local.is_customer_release ? 0 : 1
  key_vault_id       = data.azurerm_key_vault.kvl_region_lda.id
  object_id          = data.azuread_service_principal.dashboard.object_id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  secret_permissions = ["get", "list"]
}

##############################
# this sub-section assigns the read access role to the deployment dashboard managed
# identities for the customer specific keyvault. only applicable for customer releases.

# dashboard
resource "azurerm_key_vault_access_policy" "secretListCustomer" {
  count              = local.is_customer_release ? 1 : 0
  key_vault_id       = module.customerKeyvault[0].id
  object_id          = data.azuread_service_principal.dashboard.object_id
  tenant_id          = data.azurerm_client_config.current.tenant_id
  secret_permissions = ["get", "list"]
}

# ##############################
# this sub-section assigns the read access role to the deployment dashboard managed
# identities for the customer specific iot storage account. only applicable for customer releases.

# customer specific iot storage account in the customer resource group 
data "azurerm_storage_account" "sto_acc_cust_iot" {
  count               = local.is_customer_release ? 1 : 0
  name                = replace("${local.customer-lda-prefix}-iot", "-", "") # [eg. wiluatldacu1aue1iot]
  resource_group_name = local.customer-lda-rsg
}

# dashboard
resource "azurerm_role_assignment" "roles_sto_acc_cust_iot_dashboard" {
  count                = local.is_customer_release ? 1 : 0
  scope                = data.azurerm_storage_account.sto_acc_cust_iot[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_service_principal.dashboard.id
}

# ##############################
# this sub-section assigns the read access role to the deployment dashboard managed
# identities for the customer iot hub. only applicable for customer releases.

# customer iot hub
data "azurerm_iothub" "iot_hub_cust_lda" {
  count               = local.is_customer_release ? 1 : 0
  name                = "${local.customer-lda-prefix}-iot"
  resource_group_name = local.customer-lda-rsg
}

# dashboard
resource "azurerm_role_assignment" "roles_iot_hub_cust_lda_dashboard" {
  count                = local.is_customer_release ? 1 : 0
  scope                = data.azurerm_iothub.iot_hub_cust_lda[0].id
  role_definition_name = "IoT Hub Data Contributor"
  principal_id         = data.azuread_service_principal.dashboard.id
}

##############################
# this sub-section assigns the reader role to the deployment dashboard managed
# identities for the customer specific resource group. only applicable for customer releases.
data "azurerm_resource_group" "rg_customer_iot" {
  count = local.is_customer_release ? 1 : 0
  name  = local.customer-lda-rsg
}

resource "azurerm_role_assignment" "roles_reader_dashboard" {
  count                = local.is_customer_release ? 1 : 0
  role_definition_name = "Reader"
  principal_id         = data.azuread_service_principal.dashboard.id
  scope                = data.azurerm_resource_group.rg_customer_iot[0].id
}

/**********************************************************************************************/
# Create "manifestcontainer" container for each customer specific storage account to store final deployment manifest
resource "azurerm_storage_container" "manifestcontainer" {
  count                 = local.is_customer_release ? 1 : 0
  name                  = "manifestcontainer"
  storage_account_name  = replace("${local.customer-lda-prefix}-iot", "-", "")
  container_access_type = "private"
}