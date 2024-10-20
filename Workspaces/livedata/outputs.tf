output subscription_id {
  value = data.azurerm_subscription.subscription.subscription_id
}

output resource_group_name {
  value = module.az_resourcegroup.name
}

output database_password {
  sensitive = true
  value     = module.az_sqlserver.database_password
}

output appservice_host_names {
  value = module.az_appservice.host_names
}