## app service plan
variable app_service_plan_sku_tier {
  description = "Defines the Tier of app service plan sku"
  type        = string
  default     = "Standard"
}

variable app_service_plan_sku_size {
  description = "Defines the Size of app service plan sku"
  type        = string
  default     = "S1"
}

variable app_service_enable_autoscale {
  description = "If auto scale settings for app service plan should be enabled or not"
  type        = bool
  default     = false
}

## function app
variable function_app_names {
  description = "Defines the Function app names to be deployed"
  type        = list(string)
  default     = ["abc", "def"]
}

## event hub
variable eventhub_sku {
  description = "Defines which tier to use. Valid options are Basic and Standard"
  type        = string
  default     = "Standard"
}

variable eventhub_partition_sitetoplatform {
  type        = number
  description = "Specifies the current number of shards on the Site to Platform Event Hub"
  default     = 32
}

variable eventhub_partition_ptp {
  type        = number
  description = "Specifies the current number of shards on the PPMS to PDP (PTP) Event Hub"
  default     = 32
}

variable eventhub_name_ppms_to_pdp {
  type        = string
  description = "The name of the eventhub for ppms to pdp events"
  default     = "ppms-to-pdp"
}

variable eventhub_partition_unified {
  type        = number
  description = "Specifies the current number of shards on the Unified Event Hub"
  default     = 32
}

variable eventhub_message_retention {
  type        = number
  description = "Specifies the number of days to retain the events for this Event Hub. Needs to be between 1 and 7 days; or 1 day when using a Basic SKU for the parent EventHub Namespace"
  default     = 1
}

## storage account
variable storage_account_tier {
  description = "Defines the Tier of storage account to be created. Valid options are Standard and Premium."
  type        = string
  default     = "Standard"
}

variable storage_account_replication_type {
  description = "Defines the Replication Type to use for this storage account. Valid options include LRS, GRS, ZRS etc."
  type        = string
  default     = "LRS"
}

variable storage_account_create_container {
  description = "If set to true, create storage account container"
  type        = bool
  default     = true
}

variable storage_account_container_name {
  description = "Defines the Name of customer container name"
  type        = string
  default     = "rawdata"
}

## iot hub
variable iot_hub_sku_name {
  description = "Defines the IoT hub sku name"
  type        = string
  default     = "S1"
}

variable iot_hub_sku_capacity {
  description = "Defines the IoT hub sku capacity"
  type        = string
  default     = "1"
}

## rediscache
variable redis_cache_sku_name {
  description = "Redis cache sku setting i.e., Basic, Standard or Premium"
  type        = string
  default     = "Standard"
}

variable redis_cache_sku_capacity {
  description = "Size of redis cache to deploy"
  type        = number
  default     = 1
}

## log analytics
variable oms_sku {
  description = "Specifies the Sku of the Log Analytics Workspace. Possible values are Free, PerNode, Premium, Standard, Standalone, Unlimited, and PerGB2018 (new Sku as of 2018-04-03)"
  type        = string
  default     = "Free"
}

variable retention_in_days {
  description = "Number of days for which the log needs to be retained"
  type        = number
  default     = 7
}

## alerts
variable alerts_enabled {
  description = "Should the alerts be enabled?"
  type        = bool
  default     = false
}

variable thirdParty_connector_names {
  description = "Defines the Third Party Connector app names to be deployed. Comma seperated List as string"
  type        = string
  default     = ""
}

variable system_names {
  description = "Defines the Building Management System name. Comma seperated List as string"
  type        = string
  default     = ""
}

variable building_name {
  description = "Defines the Building name"
  type        = string
  default     = ""
}

variable transformation_query {
  description = "Specifies the query that will be run in the streaming job"
  type        = string
}

variable jsfunction {
  description = "Specifies the The JavaScript of this UDF Function"
  type        = string
}

variable saj_job_names {
  description = "Defines the Strean Anlaytics Job names"
  type        = list(string)
  default     = []
}

variable "deploy_function_app" {
  description = "Specifies if we should deploy a Function App or not"
  type        = bool
  default     = true
}

variable function_app_version {
  description = "The runtime version associated with the Function App"
  type        = string
  default     = "~4"
}

variable adx_cluster_resource_group {
  description = "The resource group of ADX cluster"
  type        = string
  default     = ""
}

variable adx_cluster_name {
  description = "The name of ADX cluster"
  type        = string
  default     = ""
}

variable adx_configuration_version {
  description = "The version of ADX configuration - to be changed/incremented if adx config change is to be executed"
  type        = string
  default     = "0.1"
}

variable adx_cluster_subscription_id {
  description = "The subscription id of ADX cluster"
  type        = string
  default     = ""
}

variable long_customer_name {
  description = "The full name of the Customer"
  type        = string
  default     = ""
}

variable teams_alert_email {
  description = "Email for MS Teams Alert Channel"
  type        = string
  default     = ""
}

variable twin_platform_managed_identity_principal_id {
  description = "Managed identity principal Id for twin platform"
  type        = string
}

locals {
  diagnostics_map = data.terraform_remote_state.shared.outputs.diagnostics_map

  #   s1_iot_hub_total_messages_per_day_per_unit_limit = 400000
  #   s2_iot_hub_total_messages_per_day_per_unit_limit = 6000000
  #   s3_iot_hub_total_messages_per_day_per_unit_limit = 300000000

  is_investa                              = var.customer_prefix == "inv" && terraform.workspace == "prd" && var.location == "australiaeast"
  iot_hub_sku_name                        = local.is_investa ? "S2" : var.iot_hub_sku_name
  iot_hub_sku_capacity                    = var.iot_hub_sku_capacity
  iot_alert_total_messages_used_threshold = local.is_investa ? 5900000 : 350000

  saj_job_names                           = toset(flatten([for conn_Name in split(",", var.thirdParty_connector_names) : [for system_name in split(",", var.system_names) : "${var.building_name}-${conn_Name}-${system_name}"]]))
  shared_action_group_id = data.terraform_remote_state.shared.outputs.shared_action_group_id
  shared_app_service_appserviceplan_name         = data.terraform_remote_state.shared.outputs.shared_app_service_appserviceplan_name
  shared_applicationinsights_instrumentation_key = data.terraform_remote_state.shared.outputs.shared_applicationinsights_instrumentation_key
  shared_keyvault_name                           = data.terraform_remote_state.shared.outputs.shared_keyvault_name
  shared_resourcegroup_name                      = data.terraform_remote_state.shared.outputs.shared_resourcegroup_name
}
