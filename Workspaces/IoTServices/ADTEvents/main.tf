/**********************************************************************************************/
# this section creates the function app

data "azurerm_application_insights" "appin" {
  name                = "${local.res-customer-prefix}-ain"
  resource_group_name = local.res-customer-rsg
}

data "azurerm_service_plan" "asp" {
  name                = "${local.res-customer-prefix}-asp"
  resource_group_name = local.res-customer-rsg
}

data "azurerm_storage_account" "sto" {
  name                = replace("${local.res-customer-prefix}-dia", "-", "")
  resource_group_name = local.res-customer-rsg
}

resource "azurerm_windows_function_app" "fapp" {
  name                       = "${local.res-customer-prefix}-adtevents"
  resource_group_name        = local.res-customer-rsg
  location                   = var.location
  storage_account_name       = data.azurerm_storage_account.sto.name
  storage_account_access_key = data.azurerm_storage_account.sto.primary_access_key
  service_plan_id            = data.azurerm_service_plan.asp.id
  https_only                 = true
  tags                       = local.tags

  app_settings = {
    WEBSITE_ENABLE_SYNC_UPDATE_SITE  = "true"
    WEBSITE_RUN_FROM_PACKAGE         = 1
    FUNCTIONS_EXTENSION_VERSION      = "~4"
    FUNCTIONS_WORKER_RUNTIME         = "dotnet-isolated"
    FUNCTION_APP_EDIT_MODE           = "readonly"

    # additional settings are added as part of the function deploy task in the release pipeline
  }

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                = true
    application_insights_key = data.azurerm_application_insights.appin.instrumentation_key
  }
}

/**********************************************************************************************/
# this section adds the new event hub

# import the existing event hub namespace resource
data "azurerm_eventhub_namespace" "ehub_nsp" {
  name                = "${local.res-customer-prefix}-dia"
  resource_group_name = local.res-customer-rsg
}

# create the new event hub
resource "azurerm_eventhub" "eventhub_adtevents" {
  name                = "adt-events"
  namespace_name      = data.azurerm_eventhub_namespace.ehub_nsp.name
  resource_group_name = local.res-customer-rsg
  partition_count     = 2
  message_retention   = 1
}

# create the authorization rule for the event hub
resource "azurerm_eventhub_authorization_rule" "adtevents_authrule" {
  name                = "send-listen"
  namespace_name      = data.azurerm_eventhub_namespace.ehub_nsp.name
  eventhub_name       = azurerm_eventhub.eventhub_adtevents.name
  resource_group_name = local.res-customer-rsg
  listen              = true
  send                = true
  manage              = false
}

/**********************************************************************************************/
# this section creates the new endpoint on the digital twin

# import the existing digital twin resource
data "azurerm_digital_twins_instance" "adt_instance" {
  name                = var.digital_twin_name # "${local.res-customer-prefix}-adt"
  resource_group_name = local.res-customer-rsg
}

# create the endpoint on the digital twin to forward events to the event hub
resource "azurerm_digital_twins_endpoint_eventhub" "adt_eventhub_endpoint" {
  name                                 = "adt-events"
  digital_twins_id                     = data.azurerm_digital_twins_instance.adt_instance.id
  eventhub_primary_connection_string   = azurerm_eventhub_authorization_rule.adtevents_authrule.primary_connection_string
  eventhub_secondary_connection_string = azurerm_eventhub_authorization_rule.adtevents_authrule.secondary_connection_string
}

# note: the event route is currently not supported by azurerm v3.5 and so is created
# using azure cli in a separate pipeline step. this could be moved to here in the
# future once it is supported.

/**********************************************************************************************/
# this section does some setup for the keyvault

# import the existing keyvault for the region
data "azurerm_key_vault" "kvl" {
  name                = "${local.res-region-prefix}-kvl"
  resource_group_name = local.res-region-rsg
}

# import the service principal for the function app
data "azuread_service_principal" "fapp_sp" {
  display_name = azurerm_windows_function_app.fapp.name
}

# add the access policy for the function app to the keyvault
resource "azurerm_key_vault_access_policy" "kvl_access" {
  key_vault_id   = data.azurerm_key_vault.kvl.id
  tenant_id      = azurerm_windows_function_app.fapp.identity.0.tenant_id
  object_id      = data.azuread_service_principal.fapp_sp.object_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# The following 3 secrets need to exist in the keyvault:
#   - ADTEventsFunction--ADTAuthenticationOptions--ClientSecret
#   - ADTEventsFunction--ConnectorXlAuthenticationOptions--ClientSecret
#   - ADTEventsFunction--TwinEventsEventHubConnectionString

/**********************************************************************************************/