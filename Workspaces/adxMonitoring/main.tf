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

data "azurerm_kusto_cluster" "sharedcluster" {
  name                = var.adx_cluster_name
  resource_group_name = var.adx_cluster_resource_group
  provider            = azurerm.adx
}

resource "azurerm_monitor_action_group" "adxalert" {
  name                = "CriticalAlertsAction"
  resource_group_name = var.adx_cluster_resource_group
  tags                = {customer="${var.customer_prefix}" }
  short_name          = var.project
  enabled             = var.alerts_enabled

  email_receiver {
    name          = "alertemail"
    email_address = var.adx_notification_email
  }

    webhook_receiver {
    name                    = "AlarmChannel"
    service_uri             = var.adx_notification_teams_channel
    use_common_alert_schema = true
  }
  
}

resource "azurerm_monitor_metric_alert" "Discovery_Latency" {
  name                = "Discovery-Latency"
  resource_group_name = var.adx_cluster_resource_group
  scopes              = [data.azurerm_kusto_cluster.sharedcluster.id]
  description         = "Action will be triggered when Discovery Latency is greater than 15 minutes."
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Kusto/Clusters"
    metric_name      = "DiscoveryLatency"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 900
  }

  action {
    action_group_id = azurerm_monitor_action_group.adxalert.id
  }

  depends_on = [
    azurerm_monitor_action_group.adxalert
  ]
}

resource "azurerm_monitor_metric_alert" "Ingestion_Latency" {
  name                = "Ingestion-Latency"
  resource_group_name = var.adx_cluster_resource_group
  scopes              = [data.azurerm_kusto_cluster.sharedcluster.id]
  description         = "Action will be triggered when Ingestion Latency is greater than 15 minutes."
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Kusto/Clusters"
    metric_name      = "IngestionLatencyInSeconds"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 900
  }

  action {
    action_group_id = azurerm_monitor_action_group.adxalert.id
  }

  depends_on = [
    azurerm_monitor_action_group.adxalert
  ]
}

resource "azurerm_log_analytics_workspace" "custom_laws" {
  name                = var.adx_log_analytics_workspace
  location            = var.adx_cluster_location
  resource_group_name = var.adx_cluster_resource_group
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_diagnostic_setting" "failedingestion_diagnosticsetting" {
  name               = "adxlogs-loganalytics"
  target_resource_id = data.azurerm_kusto_cluster.sharedcluster.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.custom_laws.id

  log {
    category = "FailedIngestion"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert" "failedingestionqueryrule" {
  name                = format("%s-failedingestion-queryrule", var.project_prefix)
  location            = var.adx_cluster_location
  resource_group_name = var.adx_cluster_resource_group

  action {
    action_group           = [azurerm_monitor_action_group.adxalert.id]
    email_subject          = "Failed ingestion notification"
    custom_webhook_payload = "{}"
  }
  data_source_id = azurerm_log_analytics_workspace.custom_laws.id
  description    = "Alert when total results cross threshold"
  enabled        = true
  # Query to run
  query       = <<-QUERY
FailedIngestion
| parse _ResourceId with * "providers/microsoft.kusto/clusters/" cluster_name 
| summarize count() by bin(TimeGenerated, 1h), cluster_name, Database, Table, ErrorCode, FailureStatus 
  QUERY
  severity    = 3
  frequency   = 30
  time_window = 60
  trigger {
    operator  = "GreaterThan"
    threshold = 1
  }
}