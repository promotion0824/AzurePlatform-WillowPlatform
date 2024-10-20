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

## web app
variable web_app_names {
  description = "Defines the Web app names to be deployed"
  type        = list(string)
  default     = ["app"]
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
  default     = "~3"
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

variable hybrid_connections_site_ids {
  description = "List of site id for relay hybrid connection"
  type        = string
  default     = ""
}

variable relay_management_option_name {
  description = "Name of the KeyVault Relay Management Secret"
  type        = string
  default     = "App--RelayManagementConnectionSettings"
}

locals {
  diagnostics_map = data.terraform_remote_state.shared.outputs.diagnostics_map
  relay_enabled_apps = [ "lut", "ccr", "cmn", "seb", "fct", "igi" ]
  relay_hybrid_connections = length(var.hybrid_connections_site_ids) != 0 ? format("%s%s",join("",formatlist("app_to_connector_%s,", split(",", var.hybrid_connections_site_ids))),"connector_to_app") : "connector_to_app"
}