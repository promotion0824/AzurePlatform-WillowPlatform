variable customer_resource_group_name {
  description = "Specifies the Customer specific resource group name for deployments"
  type        = string
  default     = ""
}

variable storage_account_name {
  description = "The storage account to be used by the function apps"
  type        = string
  default     = ""
}

## ADX resources
variable adx_cluster_resource_group {
  description = "Specifies the resource group the ADX Cluster belongs to"
  type        = string
  default     = ""
}

variable adx_cluster_name {
  description = "Specifies the name of the ADX Cluster"
  type        = string
  default     = ""
}

variable adx_database_name {
  description = "Specifies the name of the ADX Database"
  type        = string
  default     = ""
}

variable adx_cluster_location {
  description = "Specifies the Azure location of the ADX Cluster"
  type        = string
  default     = "australiaeast"
}

variable adx_configuration_version {
  description = "The trigger for executing the ADX Configuration script for any changes"
  type        = string
  default     = "0.1"
}

variable adx_cluster_subscription_id {
  description = "The subscription id of ADX cluster"
  type        = string
   default     = ""
}

variable alerts_enabled {
  description = "Should the action group be enabled?"
  type        = bool
  default     = true
}

variable adx_notification_teams_channel {
  description = "The teams channel for notification"
  type        = string
   default     = ""
}

variable adx_notification_email {
  description = "The email for notification"
  type        = string
   default     = ""
}

variable adx_log_analytics_workspace {
  description = "The log analytics workspace mapped to ADX cluster"
  type        = string
   default     = ""
}


locals {
  diagnostics_map = data.terraform_remote_state.shared.outputs.diagnostics_map
}
