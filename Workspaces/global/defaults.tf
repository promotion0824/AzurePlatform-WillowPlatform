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
  default     = "prj"
}

variable customer_prefix {
  description = "Short prefix for the customer. Leave empty if not customer specific"
  type        = string
  default     = ""
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
  default     = 2
}

variable zone {
  description = "Availability zone number"
  type        = number
  default     = 1
}

variable company_prefix {
  description = "Company prefix"
  type        = string
  default     = "wil"
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
