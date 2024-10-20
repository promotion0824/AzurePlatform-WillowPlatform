## common
variable location {
  description = "Location to deploy"
  type        = string
  default     = "australiaeast"
}

variable project {
  description = "Name of the project"
  type        = string
  default     = "platform"
}

variable project_prefix {
  description = "Short prefix for the project"
  type        = string
  default     = "mkp"
}

variable application_prefix {
  description = "Short prefix for the application. Leave empty if not application specific"
  type        = string
  default     = "cpt"
}

variable app_service_plan_kind {
  type        = string
  description = "The kind of the App Service Plan to create. Possible values are Windows (also available as App), Linux, elastic (for Premium Consumption) and FunctionApp (for a Consumption Plan)"
  default     = "Windows"
}

variable alerts_enabled {
  type        = bool
  description = "defines if application alerts are ennabled or not"
  default     = false
}

variable release_url {
  description = "The url of the Release Pipeline that deployed this resource"
  type        = string
  default     = ""
}

variable release_id {
  description = "The ID Release Pipeline that deployed this resource"
  type        = string
  default     = ""
}

variable tier {
  description = "Tier number to deploy"
  type        = number
  default     = 3
}

variable zone {
  description = "Availability zone number"
  type        = number
  default     = 1
}

variable state-resource-group-name {
  description = "Shared storage account resource group name"
  type        = string
}

variable state-storage-account-name {
  description = "Shared storage account name"
  type        = string
}

variable state-storage-account-sas-token {
  description = "Shared storage account sas token"
  type        = string
}

variable notification_emails {
  description = "Send Azure email notifications to"
  type        = string
  default     = ""
}