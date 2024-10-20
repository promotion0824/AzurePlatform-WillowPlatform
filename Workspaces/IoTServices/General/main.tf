# This file deals with generic customer and IoT Services specific deployments for IoT Services team

# Azure tenant
data "azurerm_client_config" "current" {}

# Get existing resource groups
data "azurerm_resource_group" "customer_rsg" {
  name = local.customer-lda-rsg
}

data "azurerm_resource_group" "regional_rsg" {
  name = local.region-lda-rsg
}

# Get customer IoTHub
data "azurerm_iothub" "customer_iothub" {
  count               = data.azurerm_resource_group.customer_rsg.id != null ? 1 : 0
  name                = "${local.customer-lda-prefix}-iot"
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
}

# Get diagnostics eventhub
data "azurerm_eventhub_namespace" "customer_dia_ehns" {
  count               = data.azurerm_resource_group.customer_rsg.id != null ? 1 : 0
  name                = "${local.customer-lda-prefix}-dia"
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
}

# Get regional Notification function app
data "azurerm_windows_function_app" "regional_notification_function_app" {
  count               = data.azurerm_resource_group.regional_rsg.id != null ? 1 : 0
  name                = "${local.region-iot-prefix}-notification-resolver-func"
  resource_group_name = data.azurerm_resource_group.regional_rsg.name
}

# Get regional Service Bus id
data "azurerm_servicebus_namespace" "regional_service_bus" {
  count               = data.azurerm_resource_group.regional_rsg.id != null ? 1 : 0
  name                = "${local.region-iot-prefix}-sbns"
  resource_group_name = data.azurerm_resource_group.regional_rsg.name
}

# Get customer specific keyvault
data "azurerm_key_vault" "customer_keyvault" {
  count               = data.azurerm_resource_group.customer_rsg.id != null ? 1 : 0
  name                = "${local.customer-iot-prefix-limited}-kvl"
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
}

# Get customer specific iothubautoscale function app
data "azurerm_windows_function_app" "customer_iothubautoscale_function_app" {
  count               = data.azurerm_resource_group.customer_rsg.id != null ? 1 : 0
  name                = "${local.customer-lda-prefix}-iothubautoscale"
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
}

# Get customer specific adaptor function app
data "azurerm_windows_function_app" "customer_adaptor_function_app" {
  count               = data.azurerm_resource_group.customer_rsg.id != null ? 1 : 0
  name                = "${local.customer-lda-prefix}-adaptortouie"
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
}

# Get customer specific unified eventhub namespace
data "azurerm_eventhub_namespace" "customer_uie_ehns" {
  count               = data.azurerm_resource_group.customer_rsg.id != null ? 1 : 0
  name                = "${local.customer-lda-prefix}-uie"
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
}

# Get customer specific unified eventhub ingestion
data "azurerm_eventhub" "customer_uie_ingestion" {
  count               = data.azurerm_resource_group.customer_rsg.id != null ? 1 : 0
  name                = "ingestion-to-adx"
  namespace_name      = data.azurerm_eventhub_namespace.customer_uie_ehns[0].name
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
}

# Get customer specific saj eventhub namespace
data "azurerm_eventhub_namespace" "customer_saj_ehns" {
  count               = data.azurerm_resource_group.customer_rsg.id != null ? 1 : 0
  name                = "${local.customer-lda-prefix}-saj"
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
}

# Create new eventhub for collecting edge metrics
resource "azurerm_eventhub" "edge_metrics_eventhub" {
  count               = data.azurerm_resource_group.customer_rsg.id != null ? 1 : 0
  name                = "edge-metrics"
  namespace_name      = data.azurerm_eventhub_namespace.customer_dia_ehns[0].name
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
  partition_count     = 2
  message_retention   = 1
}

# Create new iothub custom endpoint based on eventhub
resource "azurerm_iothub_endpoint_eventhub" "edge_metrics_endpoint" {
  count               = data.azurerm_resource_group.customer_rsg.id != null ? 1 : 0
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
  name                = "edge-metrics"
  iothub_id           = data.azurerm_iothub.customer_iothub[0].id
  connection_string   = "${data.azurerm_eventhub_namespace.customer_dia_ehns[0].default_primary_connection_string};EntityPath=${azurerm_eventhub.edge_metrics_eventhub[0].name}"
}

# Create new metrics route for iothub based on custom endpoint
resource "azurerm_iothub_route" "edge_metrics_route" {
  count               = data.azurerm_resource_group.customer_rsg.id != null ? 1 : 0
  name                = "edge-metrics"
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
  iothub_name         = data.azurerm_iothub.customer_iothub[0].name
  source              = "DeviceMessages"
  condition           = "$connectionModuleId = 'MetricsCollectorModule'"
  endpoint_names      = [azurerm_iothub_endpoint_eventhub.edge_metrics_endpoint[0].name]
  enabled             = true
}

# Grant GET/LIST permissions to customer keyvault for function app
resource "azurerm_key_vault_access_policy" "customer_keyvault_function_app" {
  count               = data.azurerm_resource_group.customer_rsg.id != null ? 1 : 0
  key_vault_id        = data.azurerm_key_vault.customer_keyvault[0].id
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = data.azurerm_windows_function_app.customer_iothubautoscale_function_app[0].identity[0].principal_id
  secret_permissions  = ["Get", "List"]
}

# Create new eventhub for mapped telemetry
resource "azurerm_eventhub" "mapped_telemetry_eventhub" {
  count               = data.azurerm_resource_group.customer_rsg.id != null ? 1 : 0
  name                = "mapped"
  namespace_name      = data.azurerm_eventhub_namespace.customer_saj_ehns[0].name
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
  partition_count     = 2
  message_retention   = 7
}

# Create consumer group for mapped telemetry
resource "azurerm_eventhub_consumer_group" "mapped_telemetry_consumer_group" {
  count               = data.azurerm_resource_group.customer_rsg.id != null ? 1 : 0
  name                = "mapped-adaptor"
  namespace_name      = data.azurerm_eventhub_namespace.customer_saj_ehns[0].name
  eventhub_name       = azurerm_eventhub.mapped_telemetry_eventhub[0].name
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
}

# Create eventhub shared access policy for sending
resource "azurerm_eventhub_authorization_rule" "mapped_telemetry_eventhub_send" {
  count               = data.azurerm_resource_group.customer_rsg.id != null ? 1 : 0
  name                = "MappedTelemetry"
  namespace_name      = data.azurerm_eventhub_namespace.customer_saj_ehns[0].name
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
  eventhub_name       = azurerm_eventhub.mapped_telemetry_eventhub[0].name
  listen              = false
  send                = true
  manage              = false
}

# Create eventhub shared access policy for listening
resource "azurerm_eventhub_authorization_rule" "mapped_telemetry_eventhub_listen" {
  count               = data.azurerm_resource_group.customer_rsg.id != null ? 1 : 0
  name                = "TelemetryProcessor"
  namespace_name      = data.azurerm_eventhub_namespace.customer_saj_ehns[0].name
  resource_group_name = data.azurerm_resource_group.customer_rsg.name
  eventhub_name       = azurerm_eventhub.mapped_telemetry_eventhub[0].name
  listen              = true
  send                = false
  manage              = false
}

# Create EventHub Data Receiver role assignment for mapped telemetry
resource "azurerm_role_assignment" "mapped_telemetry_eventhub_receiver_role_assignment" {
  count                 = data.azurerm_resource_group.customer_rsg.id != null ? 1 : 0
  scope                 = azurerm_eventhub.mapped_telemetry_eventhub[0].id
  role_definition_name  = "Azure Event Hubs Data Receiver"
  principal_id          = data.azurerm_windows_function_app.customer_adaptor_function_app[0].identity[0].principal_id
}

# Create EventHub Data Sender role assignment for mapped telemetry
resource "azurerm_role_assignment" "mapped_telemetry_eventhub_sender_role_assignment" {
  count                 = data.azurerm_resource_group.customer_rsg.id != null ? 1 : 0
  scope                 = data.azurerm_eventhub.customer_uie_ingestion[0].id
  role_definition_name  = "Azure Event Hubs Data Sender"
  principal_id          = data.azurerm_windows_function_app.customer_adaptor_function_app[0].identity[0].principal_id
}