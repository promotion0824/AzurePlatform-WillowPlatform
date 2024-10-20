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

variable app_service_plan_kind {
  type        = string
  description = "The kind of the App Service Plan to create. Possible values are Windows (also available as App), Linux, elastic (for Premium Consumption) and FunctionApp (for a Consumption Plan)"
  default     = "Windows"
}

## key vault
variable key_vault_sku_name {
  description = "Defines the SKU name for key vault. Valid options are standard and premium."
  type        = string
  default     = "standard"
}

variable aad_admin_login_name { 
  description = "Specifies the SQL server AAD admin group during pipeline deployment"
  type        = string
  default     = "Marketplace-SqlAdmin-Nonprod"
  ##aad_admin_login_name                      = "Marketplace-SqlAdmin-Prod"
  ##aad_admin_login_name                      = "Marketplace-SqlAdmin-Nonprod"
}

## web app
variable web_app_names {
  description = "Defines the Web app names to be deployed"
  type        = list(string)
  default     = ["livedataapp"]
}

## web app auth_settings
variable configuration_auth0_audience {
  description = "app_settings key"
  type        = string
  default     = ""
}

## configuration settings
variable configuration_auth0_clientid {
  description = "app_settings key"
  type        = string
  default     = ""
}

variable configuration_auth0_domain {
  description = "app_settings key"
  type        = string
  default     = ""
}

variable configuration_auth0_managementaudience {
  description = "app_settings key"
  type        = string
  default     = ""
}

variable configuration_auth0_managementclientid {
  description = "app_settings key"
  type        = string
  default     = ""
}

variable configuration_httpclientfactory_auth0_baseaddress {
  description = "app_settings key"
  type        = string
  default     = ""
}

variable configuration_dataprotection_keyvaultname {
  description = "app_settings key"
  type        = string
  default     = ""
}

variable configuration_dataprotection_storageaccountname {
  description = "app_settings key"
  type        = string
  default     = ""
}

variable configuration_storages_cachedimage_accountname {
  description = "app_settings key"
  type        = string
  default     = ""
}

variable configuration_storages_originalimage_accountname {
  description = "app_settings key"
  type        = string
  default     = ""
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

## region specific configuration settings
variable configuration_aue_auth0_clientid {
  description = "app_settings key"
  type        = string
  default     = ""
}

variable configuration_aue_auth0_clientsecret {
  description = "app_settings key"
  type        = string
  default     = ""
}

variable configuration_eu2_auth0_clientid {
  description = "app_settings key"
  type        = string
  default     = ""
}

variable configuration_eu2_auth0_clientsecret {
  description = "app_settings key"
  type        = string
  default     = ""
}


variable configuration_weu_auth0_clientid {
  description = "app_settings key"
  type        = string
  default     = ""
}

variable configuration_weu_auth0_clientsecret {
  description = "app_settings key"
  type        = string
  default     = ""
}

## sql server
variable sql_administrator_password {
  description = "The Password associated with the sql_administrator_login for the server"
  type        = string
  default     = ""
}

variable sql_database_names {
  description = "Name of sql databases"
  type        = list(string)
}

variable sql_database_edition {
  description = "Which database scaling edition the database should have."
  type        = string
  default     = "Standard"
}

variable sql_database_requested_service_objective_name {
  description = "Which service scaling objective the database should have."
  type        = string
  default     = "S1"
}

variable sql_database_zone_redundant {
  description = "Indicates if a database should be zone redundant. Only available on Premium tier and up databases."
  type        = bool
  default     = false
}

## service bus
variable servicebus_namespace_sku {
  description = "Defines which tier to use. Options are basic, standard or premium"
  type        = string
}
variable servicebus_queues {
  description = "Comma-separated name of queues to create"
  type        = string
}
variable servicebus_topics {
  description = "Comma-separated name of topics to create"
  type        = string
}
variable servicebus_queue_max_size_in_megabytes {
  default = 1024
}
variable servicebus_subscription_max_delivery_count {
  default = 2
}

locals {
  diagnostics_map = data.terraform_remote_state.shared.outputs.diagnostics_map

  platform_appservice_host_names = data.terraform_remote_state.platform.outputs.appservice_host_names
  livedata_appservice_host_names = data.terraform_remote_state.livedata.outputs.appservice_host_names

  app_settings = {
    shared = {
      "Auth0:Audience"                      = var.configuration_auth0_audience,
      "Auth0:ClientId"                      = var.configuration_auth0_clientid,
      "Auth0:Domain"                        = var.configuration_auth0_domain,
      "Auth0:ManagementAudience"            = var.configuration_auth0_managementaudience,
      "Auth0:ManagementClientId"            = var.configuration_auth0_managementclientid,
      "HttpClientFactory:Auth0:BaseAddress" = var.configuration_httpclientfactory_auth0_baseaddress,
      "DataProtection:KeyVaultName"         = var.configuration_dataprotection_keyvaultname,
      "DataProtection:StorageAccountName"   = var.configuration_dataprotection_storageaccountname
    }
    imagehub = {
      "Storages:CachedImage:AccountName"   = var.configuration_storages_cachedimage_accountname,
      "Storages:OriginalImage:AccountName" = var.configuration_storages_originalimage_accountname
    }
    xl = {
      ## marketplace core app service
      "HttpClientFactory:MarketPlaceCore:BaseAddress" = "https://${module.az_globalvars.resource_prefix}core.azurewebsites.net/"
    }
    core = {
      ## marketplace DB connection string
      "ConnectionStrings:MarketPlaceDb" = "Server=${module.az_globalvars.resource_prefix}sql.database.windows.net;Database=${var.sql_database_names[0]};MultipleActiveResultSets=true"
    }
    lookup = {
      "HttpClientFactory:SiteCore:BaseAddress"  = "https://${[for x in local.platform_appservice_host_names : x if length(regexall(".*sitecore.*", x)) > 0][0]}/",
      "MarketplaceCoreAssemblyNameInclVersion"  = "MarketplaceCoreApi--1",
      "Azure:BlobStorage:ContainerName"         = "lookup-data-dumps",
      "Azure:KeyVault:KeyVaultName"             = "${module.az_globalvars.resource_prefix}kvl"
    }
    publicapi = {
      ## app services from Platform
      "HttpClientFactory:MarketPlaceCore:BaseAddress" = "https://${module.az_globalvars.resource_prefix}core.azurewebsites.net/",
      "HttpClientFactory:ConnectorCore:BaseAddress" = "https://${[for x in local.livedata_appservice_host_names : x if length(regexall(".*connectorcore.*", x)) > 0][0]}/",
      "HttpClientFactory:LiveDataCore:BaseAddress"  = "https://${[for x in local.livedata_appservice_host_names : x if length(regexall(".*livedatacore.*", x)) > 0][0]}/",
      "HttpClientFactory:AssetCore:BaseAddress"     = "https://${[for x in local.platform_appservice_host_names : x if length(regexall(".*assetcore.*", x)) > 0][0]}/",
      "HttpClientFactory:DirectoryCore:BaseAddress" = "https://${[for x in local.platform_appservice_host_names : x if length(regexall(".*directorycore.*", x)) > 0][0]}/",
      "HttpClientFactory:InsightCore:BaseAddress"   = "https://${[for x in local.platform_appservice_host_names : x if length(regexall(".*insightcore.*", x)) > 0][0]}/",
      "HttpClientFactory:SiteCore:BaseAddress"      = "https://${[for x in local.platform_appservice_host_names : x if length(regexall(".*sitecore.*", x)) > 0][0]}/",
      "HttpClientFactory:WorkflowCore:BaseAddress"  = "https://${[for x in local.platform_appservice_host_names : x if length(regexall(".*workflowcore.*", x)) > 0][0]}/"
    }
  }

  keyvault_secrets = {
    shared = {
      "PublicApi--1--Regions--${module.az_globalvars.location_prefix}--MachineToMachineAuthentication--Domain"   = var.configuration_auth0_domain,
      "PublicApi--1--Regions--${module.az_globalvars.location_prefix}--MachineToMachineAuthentication--Audience" = var.configuration_auth0_audience
    }
    aue = {
      "PublicApi--1--Regions--${module.az_globalvars.location_prefix}--MachineToMachineAuthentication--ClientId"     = var.configuration_aue_auth0_clientid,
      "PublicApi--1--Regions--${module.az_globalvars.location_prefix}--MachineToMachineAuthentication--ClientSecret" = var.configuration_aue_auth0_clientsecret
    }
    eu2 = {
      "PublicApi--1--Regions--${module.az_globalvars.location_prefix}--MachineToMachineAuthentication--ClientId"     = var.configuration_eu2_auth0_clientid,
      "PublicApi--1--Regions--${module.az_globalvars.location_prefix}--MachineToMachineAuthentication--ClientSecret" = var.configuration_eu2_auth0_clientsecret
    }
    weu = {
      "PublicApi--1--Regions--${module.az_globalvars.location_prefix}--MachineToMachineAuthentication--ClientId"     = var.configuration_weu_auth0_clientid,
      "PublicApi--1--Regions--${module.az_globalvars.location_prefix}--MachineToMachineAuthentication--ClientSecret" = var.configuration_weu_auth0_clientsecret
    }
  }
}
