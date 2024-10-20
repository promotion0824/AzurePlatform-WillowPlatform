/**********************************************************************************************/
# Create keyvault for each namespace and provide access to managed identities

# This should be managed under DeploymentDashboard-K8S workspace but there are dependencies on
# azuread and azurerm versions when using the terraform-modules to create keyvault

data "azuread_service_principal" "dashboard_dev_identity" {
  display_name = "edgedeployment-dashboard-dev-pod-id"
}

data "azuread_service_principal" "dashboard_prd_identity" {
  display_name = "edgedeployment-dashboard-prd-pod-id"
}

data "azurerm_client_config" "current" {}

locals {
  namespaces = [
    {
      env     = "dev"
      rsg     = "deployment-dashboard-dev-rsg"
      id      = data.azuread_service_principal.dashboard_dev_identity.id
      principal_id = data.azuread_service_principal.dashboard_dev_identity.object_id
    },
    {
      env     = "prd"
      rsg     = "deployment-dashboard-prd-rsg"
      id      = data.azuread_service_principal.dashboard_prd_identity.id
      principal_id = data.azuread_service_principal.dashboard_prd_identity.object_id
    }
  ]
}

module "dashboardKeyvault" {
  location            = var.location
  tags                = local.tags
  source              = "../../../terraform-modules/azurerm/keyvault"
  
  for_each = {
    for i, v in local.namespaces : i => v
  }
  resource_group_name = each.value.rsg
  resource_prefix     = "deploy-dashboard-${each.value.env}-"
}

# Add access policies to keyvault
resource "azurerm_key_vault_access_policy" "secretList" {
  tenant_id    = data.azurerm_client_config.current.tenant_id
  secret_permissions = ["get", "list"]
  for_each = {
    for i, v in module.dashboardKeyvault : i => v
  }
  key_vault_id = each.value.id
  object_id = length(regexall("prd", each.value.name)) > 0 ? data.azuread_service_principal.dashboard_prd_identity.object_id : data.azuread_service_principal.dashboard_dev_identity.object_id
}

# Grant full access to KeyVault admin group for PRD
data "azuread_group" "keyvaultAdminGroup" {
  display_name = "Azure-K8S-INTERNAL-KV-Admin"
}

resource "azurerm_key_vault_access_policy" "keyvaultAdmin" {
  for_each = {
    for i, v in module.dashboardKeyvault : i => v
          if length(regexall("prd", v.name)) > 0
  }
  key_vault_id    = each.value.id
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