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

variable deploy_function_app {
  description = "Specifies if we should deploy a Function App or not"
  type        = bool
  default     = false
}

## event hub
variable eventhub_sku {
  description = "Defines which tier to use. Valid options are Basic and Standard"
  type        = string
  default     = "Standard"
}

variable eventhub_partition {
  type        = number
  description = "Specifies the current number of shards on the Event Hub"
  default     = 1
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

## postgresql
variable postgresql_server_name {
  description = "The name of the PostgreSQL Server"
  type        = string
  default     = "pgs"
}

variable postgresql_database_name {
  description = "The name of the PostgreSQL Database, which needs to be a valid PostgreSQL identifier. Changing this forces a new resource to be created."
  type        = string
}

variable postgresql_sku_name {
  description = "Specifies the SKU Name for this PostgreSQL Server. The name of the SKU, follows the tier + family + cores pattern (e.g. B_Gen4_1, GP_Gen5_8)."
  type        = string
}

variable postgresql_administrator_password {
  description = "The Password associated with the postgresql_administrator_login for the server"
  type        = string
}

variable postgresql_storage_mb {
  description = "Max storage allowed for a server. Possible values are between 5120 MB(5GB) and 1048576 MB(1TB) for the Basic SKU and between 5120 MB(5GB) and 4194304 MB(4TB) for General Purpose/Memory Optimized SKUs."
  type        = number
}

variable postgresql_backup_retention_days {
  description = "Backup retention days for the server, supported values are between 7 and 35 days."
  type        = number
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
  description = "Defines the Stream Analytics Job names"
  type        = list(string)
  default     = []
}

variable skip_iot_resource_group_creation {
  description = "Skips creating resource group via Terraform (if already created by other means)"
  type        = bool
  default     = false
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
}
