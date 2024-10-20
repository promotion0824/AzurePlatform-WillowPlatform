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

locals {
  diagnostics_map = data.terraform_remote_state.shared.outputs.diagnostics_map
}
