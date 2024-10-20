## app service plan
variable app_service_plan_sku_tier_livedata {
  description = "Defines the Tier of app service plan sku for LiveData apps"
  type        = string
  default     = "Basic"
}

variable app_service_plan_sku_size_livedata {
  description = "Defines the Size of app service plan sku for LiveData apps"
  type        = string
  default     = "B1"
}

variable app_service_enable_autoscale {
  description = "If auto scale settings for app service plan should be enabled or not"
  type        = bool
  default     = false
}

variable app_service_autoscale_maximum_capacity_livedata {
  type        = number
  description = "The maximum number of instances for LiveData app service plan. Valid values are between 0 and 1000"
  default     = 5
}

variable app_service_plan_kind {
  type        = string
  description = "The kind of the App Service Plan to create. Possible values are Windows (also available as App), Linux, elastic (for Premium Consumption) and FunctionApp (for a Consumption Plan)"
  default     = "Windows"
}

## key vault
variable key_vault_sku_name {
  description = "Defines the SKU name for key vault. Valid options are standard and premium."
  type        = string
  default     = "standard"
}

## function app
variable function_app_names {
  description = "Defines the Function app names to be deployed"
  type        = list(string)
}

variable function_app_version {
  description = "The runtime version associated with the Function App"
  type        = string
}

variable deploy_function_app {
  description = "Specifies if we should deploy a Function App or not"
  type        = bool
  default     = true
}

variable aad_admin_login_name { 
  description = "Specifies the SQL server AAD admin group during pipeline deployment"
  type        = string
  default     = "IoT-SqlAdmin-Nonprod"
  ##aad_admin_login_name                      = "IoT-SqlAdmin-Nonprod"
  ##aad_admin_login_name                      = "IoT-SqlAdmin-Prod"
}

## web app
variable web_app_names {
  description = "Defines the Web app names to be deployed"
  type        = list(string)
  default     = ["livedataapp"]
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

## sql server
variable sql_administrator_password {
  description = "The Password associated with the sql_administrator_login for the server"
  type        = string
}

variable sql_database_names {
  description = "Name of sql databases"
  type        = list(string)
}

variable sql_database_edition_livedata {
  description = "Which database scaling edition the database should have."
  type        = string
}

variable sql_database_requested_service_objective_name_livedata {
  description = "Which service scaling objective the database should have."
  type        = string
}

locals {
  diagnostics_map = data.terraform_remote_state.shared.outputs.diagnostics_map
}
