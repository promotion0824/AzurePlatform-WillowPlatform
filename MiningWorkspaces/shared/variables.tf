## key vault
variable "key_vault_sku_name" {
  description = "Defines the SKU name for key vault. Valid options are standard and premium."
  type        = string
  default     = "standard"
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

## alerts
variable "alerts_enabled" {
  description = "Should the action group be enabled?"
  type        = bool
  default     = false
}

## log analytics
variable "oms_sku" {
  description = "Specifies the Sku of the Log Analytics Workspace. Possible values are Free, PerNode, Premium, Standard, Standalone, Unlimited, and PerGB2018 (new Sku as of 2018-04-03)"
  type        = string
  default     = "Free"
}

variable "retention_in_days" {
  description = "Number of days for which the log needs to be retained"
  type        = number
  default     = 7
}

#------------------------------------------------------------------------------------
# Begin Mining changes
# Define variables for shared resources based on existing workspace definitions
#------------------------------------------------------------------------------------

variable "sql_aad_admin_login_name" {
  description = "Login group assigned admin and read access to database. SQL module default it to Engineers_Willow if not supplied"
  type        = string
  default     = "Mining-SqlAdmin-Nonprod"
}

variable sql_configuration_version {
  description = "The version of ADX configuration - to be changed/incremented if adx config change is to be executed"
  type        = string
  default     = "0.1"
}

variable twinPlatformManagedIdentityPrincipalId {
  description = "Managed identity principal Id for twin platform"
  type        = string
}

variable authApiManagedIdentityPrincipalId {
  description = "Managed identity principal Id for authorization api"
  type        = string
}

locals {
  tags = merge(
    module.az_globalvars.tags,
    map(
      "function", "diagnostics"
    )
  )
}

#App Service plan - copied from customers/variables.tf
variable "app_service_plan_sku_tier" {
  description = "Defines the Tier of app service plan sku"
  type        = string
  default     = "Standard"
}

variable "app_service_plan_sku_size" {
  description = "Defines the Size of app service plan sku"
  type        = string
  default     = "S3"
}

variable "app_service_enable_autoscale" {
  description = "If auto scale settings for app service plan should be enabled or not"
  type        = bool
  default     = false
}

#SQL Azure Database - copied from applications/variables.tf
variable "sql_administrator_password" {
  description = "The Password associated with the sql_administrator_login for the server"
  type        = string
}

variable "sql_database_edition" {
  description = "Which database scaling edition the database should have."
  type        = string
  default     = "Standard"
}

variable "sql_database_requested_service_objective_name" {
  description = "Which service scaling objective the database should have."
  type        = string
  default     = "S3"
}

variable "app_insights_daily_data_cap_in_gb" {
  description = "Specifies the Application Insights component daily data volume cap in GB."
  type        = number
  default     = 1
}

#Dont think this is needed as we're not creating databases just server?
#variable sql_database_names {
#  description = "Name of sql databases"
#  type        = list(string)
#}

#Used by sql but ignore for now
# locals {
#   diagnostics_map = data.terraform_remote_state.shared.outputs.diagnostics_map
# }

#------------------------------------------------------------------------------------
# End Mining Changes
#------------------------------------------------------------------------------------