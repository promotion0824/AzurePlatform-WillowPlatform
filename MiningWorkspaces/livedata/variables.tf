## function app
variable "function_app_names" {
  description = "Defines the Function app names to be deployed"
  type        = list(string)
}

variable "function_app_version" {
  description = "The runtime version associated with the Function App"
  type        = string
}

variable "deploy_function_app" {
  description = "Specifies if we should deploy a Function App or not"
  type        = bool
  default     = true
}

## web app
variable "web_app_names" {
  description = "Defines the Web app names to be deployed"
  type        = list(string)
  default     = ["livedataapp"]
}

## storage account
variable "storage_account_tier" {
  description = "Defines the Tier of storage account to be created. Valid options are Standard and Premium."
  type        = string
  default     = "Standard"
}

variable "storage_account_replication_type" {
  description = "Defines the Replication Type to use for this storage account. Valid options include LRS, GRS, ZRS etc."
  type        = string
  default     = "LRS"
}

variable "storage_account_create_container" {
  description = "If set to true, create storage account container"
  type        = bool
  default     = true
}

variable "storage_account_container_name" {
  description = "Defines the Name of shared container name"
  type        = string
  default     = "logs"
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

locals {
  diagnostics_map                                = data.terraform_remote_state.shared.outputs.diagnostics_map
  shared_app_service_appserviceplan_name         = data.terraform_remote_state.shared.outputs.shared_app_service_appserviceplan_name
  shared_applicationinsights_instrumentation_key = data.terraform_remote_state.shared.outputs.shared_applicationinsights_instrumentation_key
  shared_applicationinsights_id                  = data.terraform_remote_state.shared.outputs.shared_applicationinsights_id
  shared_keyvault_name                           = data.terraform_remote_state.shared.outputs.shared_keyvault_name
  shared_resourcegroup_name                      = data.terraform_remote_state.shared.outputs.shared_resourcegroup_name
  shared_storageaccount_name                     = data.terraform_remote_state.shared.outputs.shared_storageaccount_name
}