## app service plan
variable app_service_plan_sku_tier_platform {
  description = "Defines the Tier of app service plan sku for Platform apps"
  type        = string
  default     = "Standard"
}

variable app_service_plan_sku_size_platform {
  description = "Defines the Size of app service plan sku for Platform apps"
  type        = string
  default     = "S1"
}

variable app_service_enable_autoscale {
  description = "If auto scale settings for app service plan should be enabled or not"
  type        = bool
  default     = false
}

## key vault
variable key_vault_sku_name {
  description = "Defines the SKU name for key vault. Valid options are standard and premium."
  type        = string
  default     = "standard"
}

## web app
variable web_app_names {
  description = "Defines the Web app names to be deployed"
  type        = list(string)
  default     = ["platform"]
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
  description = "Defines the Name of shared container name"
  type        = string
  default     = "logs"
}

variable storage_account_enable_data_protection {
  type        = bool
  description = "Enable blob snapshots"
  default     = false
}

variable storage_account_retention_days {
  type        = number
  description = "Retention period indicates the amount of time that soft deleted data is stored and available for recovery. You can retain soft deleted data for between 1 and 365 days"
  default     = 7
}

## sql server
variable sql_administrator_password {
  description = "The Password associated with the sql_administrator_login for the server"
  type        = string
}

variable sql_database_names {
  description = "Name of sql databases"
  type        = list(string)
}

variable sql_database_edition {
  description = "Which database scaling edition the database should have."
  type        = string
  default     = "Standard"
}

variable sql_database_requested_service_objective_name {
  description = "Which service scaling objective the database should have."
  type        = string
  default     = "S1"
}

## notification hub
variable notification_hub_sku_name {
  description = "The name of the SKU to use for this Notification Hub Namespace. Possible values are Free, Basic or Standard. Changing this forces a new resource to be created."
  type        = string
  default     = "Free"
}

variable notification_hub_apns_bundle_id {
  description = "The Bundle ID of the iOS/macOS application to send push notifications for, such as com.hashicorp.example"
  type        = string
}

variable notification_hub_apns_key_id {
  description = "The Apple Push Notifications Service (APNS) Key."
  type        = string
}

variable notification_hub_apns_token {
  description = "The Push Token associated with the Apple Developer Account."
  type        = string
}

variable notification_hub_gcm_api_key {
  description = "The API Key associated with the Google Cloud Messaging service."
  type        = string
}

## function app
variable function_app_names {
  description = "Defines the Function app names to be deployed"
  type        = list(string)
}

variable function_app_version {
  description = "The runtime version associated with the Function App"
  type        = string
  default     = "~3"
}

locals {
  diagnostics_map = data.terraform_remote_state.shared.outputs.diagnostics_map
}
