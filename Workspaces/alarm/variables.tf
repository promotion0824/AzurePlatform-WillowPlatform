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

variable app_service_plan_kind {
  type        = string
  description = "The kind of the App Service Plan to create. Possible values are Windows (also available as App), Linux, elastic (for Premium Consumption) and FunctionApp (for a Consumption Plan)"
  default     = "FunctionApp"
}

## function app
variable function_app_names {
  description = "Defines the Function app names to be deployed"
  type        = list(string)
  default     = ["app"]
}

variable function_app_version {
  description = "The runtime version associated with the Function App"
  type        = string
  default     = "~2"
}

variable deploy_function_app {
  description = "Specifies if we should deploy a Function App or not"
  type        = bool
  default     = false
}

## key vault
variable key_vault_sku_name {
  description = "Defines the SKU name for key vault. Valid options are standard and premium."
  type        = string
  default     = "standard"
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

locals {
  diagnostics_map = data.terraform_remote_state.shared.outputs.diagnostics_map
}
