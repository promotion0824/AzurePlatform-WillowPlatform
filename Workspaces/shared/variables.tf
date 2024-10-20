## key vault
variable key_vault_sku_name {
  description = "Defines the SKU name for key vault. Valid options are standard and premium."
  type        = string
  default     = "standard"
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
  default     = 2
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
  description = "Defines the Name of shared container name"
  type        = string
  default     = "logs"
}

## log analytics
variable oms_sku {
  description = "Specifies the Sku of the Log Analytics Workspace. Possible values are Free, PerNode, Premium, Standard, Standalone, Unlimited, and PerGB2018 (new Sku as of 2018-04-03)"
  type        = string
  default     = "Standalone"
}

variable retention_in_days {
  description = "Number of days for which the log needs to be retained"
  type        = number
  default     = 7
}

## alerts
variable alerts_enabled {
  description = "Should the action group be enabled?"
  type        = bool
  default     = false
}


locals {
  tags = merge(
    module.az_globalvars.tags,
    map(
      "function", "diagnostics"
    )
  )
}
