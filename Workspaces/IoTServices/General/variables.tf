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

variable "customer" {
  description = "Name of the customer"
  type        = string
  default     = "customer"
}

variable "customer_prefix" {
  description = "Short prefix for the customer"
  type        = string
  default     = ""
}

variable "is_application" {
  description = "If set to true, add application tag instead of customer tag"
  type        = bool
  default     = false
}

variable "tags" {
  description = "A map of the tags to use for the resources that are deployed"
  type        = map(any)
  default = {
    company = "willow"
  }
}

locals {
  location-short       = lookup(var.location_prefix, var.location)
  company              = lower(var.company)
  project              = lower(var.project)
  customer             = lower(var.customer)
  tier                 = "t${var.tier}"
  company-prefix       = lower(var.company_prefix)
  customer-prefix      = lower(var.customer_prefix)
  cust-prefix-limited  = lower(substr(var.customer_prefix, 0, 3))      # some resource names are length limited (eg. keyvaults)
  env-prefix           = lower(terraform.workspace)                    # eg. dev
  company-env          = "${local.company-prefix}-${local.env-prefix}" # eg. wil-uat
  location-zone        = "${local.location-short}${var.zone}"          # eg. aue1
  is_customer_release  = length(var.customer_prefix) > 0               # whether this release is being run in the context of a customer

  /*****************************************************************************************************************/
  # some useful calculated strings:

  # prefix for livedata resources that are deployed for an entire region
  region-lda-prefix = "${local.company-env}-lda-${local.location-zone}" # eg. wil-uat-lda-aue1

  # livedata region resource group name
  region-lda-rsg = "${local.tier}-${local.region-lda-prefix}-app-rsg" # eg. t3-wil-uat-lda-aue1-app-rsg

  # prefix for livedata resources that are deployed for a specific customer
  customer-lda-prefix = "${local.company-env}-lda-${local.customer-prefix}-${local.location-zone}" # eg. wil-uat-lda-cu1-aue1

  # livedata customer resource group name
  customer-lda-rsg = "${local.tier}-${local.customer-lda-prefix}-app-rsg" #eg. t3-wil-uat-lda-cu1-aue1-app-rsg

  # prefix for iot team resources that are deployed for an entire region
  region-iot-prefix = "${local.company-env}-iot-${local.location-zone}" # eg. wil-uat-iot-aue1

  # prefix for iot team resources that are deployed for a specific customer
  customer-iot-prefix = "${local.company-env}-iot-${local.customer-prefix}-${local.location-zone}" # eg. wil-uat-iot-cu1-aue1

  # prefix for iot team resources that are character limited
  customer-iot-prefix-limited = "${local.company-env}-iot-${local.cust-prefix-limited}-${local.location-zone}" # eg. wil-uat-iot-cu1-aue1

  # prefix for livedata resources that are character limited
  customer-lda-prefix-limited = "${local.company-env}-lda-${local.cust-prefix-limited}-${local.location-zone}" # eg. wil-uat-lda-cu1-aue1

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

  tags-customer = merge(
    local.tags-common,
    var.is_application == true ?
    tomap({
      "application" = local.customer-prefix
    }) :
    tomap({
      "customer" = local.customer-prefix
    })
  )

  tags = var.customer_prefix != "" ? local.tags-customer : local.tags-common
}