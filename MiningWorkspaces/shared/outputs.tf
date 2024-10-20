output "subscription_id" {
  value = data.azurerm_subscription.subscription.subscription_id
}

output "environment" {
  value = terraform.workspace
}

output "shared_diagnostics_resource_group_name" {
  value = module.az_resourcegroup.name
}

output "shared_diagnostics_keyvault_name" {
  value = module.az_keyvault.name
}

output "shared_action_group_id" {
  value = module.az_actiongroup.id
}

output "diagnostics_map" {
  depends_on = [
    module.az_storageaccount_diag,
    module.az_loganalytics_diag,
  ]

  value = (map(
    "sa_id", module.az_storageaccount_diag.id,
    "la_id", module.az_loganalytics_diag.resource_id,
    "rg_name", module.az_resourcegroup.name,
    "sa_name", module.az_storageaccount_diag.name,
    "la_name", module.az_loganalytics_diag.name,
  ))
}

#shared app service
output "shared_resourcegroup_name" {
  value = module.az_resourcegroup.name
}

output "shared_app_service_appserviceplan_name" {
  value = module.az_appserviceplan.name
}

#shared key vault
output "shared_keyvault_name" {
  value = module.az_keyvault.name
}

#shared storage
output "shared_storageaccount_name" {
  value = module.az_storageaccount.name
}

#shared application insights
output "shared_applicationinsights_instrumentation_key" {
  value = module.az_applicationinsights.instrumentation_key
}

output "shared_applicationinsights_id" {
  value = module.az_applicationinsights.id
}

output "shared_sql_server_fqdn" {
  value = module.az_sqlserver.sql_server_fqdn
}

output "shared_storage_account" {
  value = module.az_storageaccount.name
}

output "company_prefix" {
  value = module.az_globalvars.company_prefix
}

output "env_prefix" {
  value = module.az_globalvars.env_prefix
}

output "location_prefix" {
  value = module.az_globalvars.location_with_zone_prefix
}
