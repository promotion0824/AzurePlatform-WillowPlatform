## web app
variable web_app_names {
  description = "Defines the Web app names to be deployed"
  type        = list(string)
  default     = ["mining"]
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

variable storage_account_container_name_original {
  description = "Defines the Name of container for original files"
  type        = string
  default     = "original"
}

variable storage_account_container_name_cached {
  description = "Defines the Name of container for cached files"
  type        = string
  default     = "cached"
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

variable "deploy_function_app" {
  description = "Specifies if we should deploy a Function App or not"
  type        = bool
  default     = true
}

locals {
  diagnostics_map = data.terraform_remote_state.shared.outputs.diagnostics_map

  shared_app_service_appserviceplan_name          = data.terraform_remote_state.shared.outputs.shared_app_service_appserviceplan_name
  shared_applicationinsights_instrumentation_key  = data.terraform_remote_state.shared.outputs.shared_applicationinsights_instrumentation_key
  shared_applicationinsights_id                   = data.terraform_remote_state.shared.outputs.shared_applicationinsights_id
  shared_keyvault_name                            = data.terraform_remote_state.shared.outputs.shared_keyvault_name
  shared_storageaccount_name                      = data.terraform_remote_state.shared.outputs.shared_storageaccount_name
  shared_resourcegroup_name                       = data.terraform_remote_state.shared.outputs.shared_resourcegroup_name
}
