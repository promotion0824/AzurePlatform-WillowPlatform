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

## data factory
variable adf_vsts_branch_name {
  description = "Specifies the branch of the repository to get code from"
  type        = string
  default     = "master"
}
variable adf_vsts_project_name {
  description = "Specifies the name of the VSTS project"
  type        = string
  default     = "Innovation"
}
variable adf_vsts_repository_name {
  description = "Specifies the name of the git repository"
  type        = string
  default     = "Innovation"
}
variable adf_vsts_root_folder {
  description = "Specifies the root folder within the repository. Set to / for the top level"
  type        = string
  default     = "/"
}

locals {
  diagnostics_map = data.terraform_remote_state.shared.outputs.diagnostics_map
}
