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

variable notification_emails {
  description = "Send Azure email notifications to"
  type        = string
  default     = ""
}
