## global variables - override where necessary
variable "company" {
  description = "Company name"
  type        = string
  default     = "willow"
}

variable "company_prefix" {
  description = "Company prefix"
  type        = string
  default     = "wil"
}

variable "location" {
  description = "Location to deploy"
  type        = string
  default     = "australiaeast"
}

variable "location_prefix" {
  description = "Short prefix for location"
  type        = map(any)
  default = {
    "australiaeast" = "aue",
    "eastus2"       = "eu2",
    "westeurope"    = "weu",
  }
}

variable "tier" {
  description = "Tier number to deploy"
  type        = number
  default     = 3
}

variable "zone" {
  description = "Availability zone number"
  type        = number
  default     = 1
}

variable "project" {
  description = "Name of the project"
  type        = string
  default     = "livedata"
}

variable "project_prefix" {
  description = "Short prefix for the project"
  type        = string
  default     = "lda"
}

variable "tags" {
  description = "A map of the tags to use for the resources that are deployed"
  type        = map(any)
  default = {
    company   = "willow",
    managedby = "terraform"
  }
}

################################################################################################

locals {
  location-short = lookup("${var.location_prefix}", "${var.location}")
  company        = lower(var.company)
  project        = lower(var.project)
  tier           = "t${var.tier}"
  env-prefix     = lower(terraform.workspace)

  tags-common = merge(
    var.tags,
    tomap({
      "environment" = terraform.workspace,
      "location"    = var.location,
      "project"     = local.project,
      "zone"        = var.zone,
      "tier"        = var.tier
    })
  )

  tags = local.tags-common
}