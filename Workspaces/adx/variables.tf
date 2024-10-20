## function app
variable function_app_names {
  description = "Defines the Function app names to be deployed"
  type        = list(string)
  default     = ["abc", "def"]
}

variable deploy_function_app {
  description = "Specifies if we should deploy a Function App or not"
  type        = bool
  default     = false
}

variable eventhub_message_retention {
  type        = number
  description = "Specifies the number of days to retain the events for this Event Hub. Needs to be between 1 and 7 days; or 1 day when using a Basic SKU for the parent EventHub Namespace"
  default     = 7
}

variable "eventhub_capture_enable" {
  description = "Specifies if Capture functionality should be enabled for the eventhub"
  type        = bool
  default     = false 
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

variable create_adx_database {
  description = "Specifies if the ADX database needs to be created (skip if created outside of TF)"
  type        = bool
  default     = false 
}

variable skip_telemetry_data_connection {
  description = "Specifies if the Telemetry table data connection needs to be created or skipped (skip if created outside of TF)"
  type        = bool
  default     = false
}

variable skip_external_events {
  description = "Specifies if there are no external events integrations (SAJs) for the customer"
  type        = bool
  default     = false
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

variable adx_principal_id {
  description = "The ADX cluster Object ID(Principal) ID"
  type        = string
  default     = ""
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

variable "tags" {
  description = "A map of the tags to use for the resources that are deployed"
  type        = map(any)
  default = {
    company = "willow"
  }
}

locals {
  diagnostics_map = data.terraform_remote_state.shared.outputs.diagnostics_map
}

locals {
  location-short       = lookup(var.location_prefix, var.location)
  project              = lower(var.project)
  tier                 = "t${var.tier}"
  company-prefix       = lower("wil")
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
    tomap({
      "customer" = local.customer-prefix
    })
  )

  tags = var.customer_prefix != "" ? local.tags-customer : local.tags-common
}