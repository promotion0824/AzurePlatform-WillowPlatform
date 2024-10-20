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

variable "project" {
  description = "Name of the project"
  type        = string
  default     = "platform"
}

variable "project_prefix" {
  description = "Short prefix for the project"
  type        = string
  default     = "lda"
}

variable "customer" {
  description = "Name of the customer"
  type        = string
  default     = "Customer"
}

variable "customer_prefix" {
  description = "Short prefix for the customer"
  type        = string
  default     = "cu1"
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

variable "tags" {
  description = "A map of the tags to use for the resources that are deployed"
  type        = map(any)
  default = {
    company   = "willow"
    managedby = "terraform"
  }
}

################################################################################################

variable "digital_twin_name" {
  description = "The name of the Azure Digital Twin resource"
  type        = string
  default     = ""
}

locals {
  location-short  = lookup("${var.location_prefix}", "${var.location}")
  company         = lower(var.company)
  project         = lower(var.project)
  customer        = lower(var.customer)
  tier            = "t${var.tier}"
  company-prefix  = lower(var.company_prefix)
  project-prefix  = lower(var.project_prefix)
  customer-prefix = lower(var.customer_prefix)
  env-prefix      = lower(terraform.workspace)
  company-env-prj = "${local.company-prefix}-${local.env-prefix}-${local.project-prefix}"

  # prefix for resources that are deployed for an entire region
  res-region-prefix = "${local.company-env-prj}-${local.location-short}${var.zone}"

  # region resource group name
  res-region-rsg = "${local.tier}-${local.res-region-prefix}-app-rsg"

  # prefix for resources that are deployed for a specific customer
  res-customer-prefix = "${local.company-env-prj}-${local.customer-prefix}-${local.location-short}${var.zone}"

  # customer resource group name
  res-customer-rsg = "${local.tier}-${local.res-customer-prefix}-app-rsg"

  tags-common = merge(
    var.tags,
    tomap({
      "environment" = terraform.workspace,
      "location"    = var.location,
      "project"     = local.project,
      "customer"    = local.customer,
      "zone"        = var.zone,
      "tier"        = var.tier,
      "release-id"  = var.release_id,
      "release-url" = var.release_url
    })
  )

  tags = local.tags-common
}