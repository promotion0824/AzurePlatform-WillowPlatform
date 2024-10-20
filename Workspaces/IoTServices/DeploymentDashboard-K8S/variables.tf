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

variable "sql_db_sku_dev" {
  description = "The SKU for the Deployment Dashboard SQL Database. Use Gen 5 for serverless"
  type        = string
  default     = "GP_S_Gen5_1"
}

variable "sql_db_min_capacity_dev" {
  description = "The minimum capacity for the Deployment Dashboard SQL Database"
  type        = number
  default     = 0.5
}

variable "sql_db_max_size_gb_dev" {
  description = "The maximum size (in GB) for the Deployment Dashboard SQL Database"
  type        = number
  default     = 2
}

variable "sql_db_pause_delay_minutes_dev" {
  description = "The auto pause delay (in minutes) for the Deployment Dashboard SQL Database"
  type        = number
  default     = 240
}

variable "sql_db_sku_prd" {
  description = "The SKU for the Deployment Dashboard SQL Database. Use Gen 5 for serverless"
  type        = string
  default     = "GP_S_Gen5_1"
}

variable "sql_db_min_capacity_prd" {
  description = "The minimum capacity for the Deployment Dashboard SQL Database"
  type        = number
  default     = 0.5
}

variable "sql_db_max_size_gb_prd" {
  description = "The maximum size (in GB) for the Deployment Dashboard SQL Database"
  type        = number
  default     = 2
}

variable "sql_db_pause_delay_minutes_prd" {
  description = "The auto pause delay (in minutes) for the Deployment Dashboard SQL Database"
  type        = number
  default     = 240
}

variable "tags" {
  description = "A map of the tags to use for the resources that are deployed"
  type        = map(any)
  default = {
    company   = "willow",
    managedby = "terraform"
  }
}

variable "release_url" {
  description = "The url of the Release Pipeline that deployed this resource"
  type        = string
  default     = ""
}

variable "release_id" {
  description = "The ID of the Release Pipeline that deployed this resource"
  type        = string
  default     = ""
}

variable "forwarding_function_system_identity_list" {
  description = "The list of system identities of the forwarding functions to assign roles to"
  type        = string
  default     = ""
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