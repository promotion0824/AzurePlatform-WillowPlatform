output "subscription_id" {
  value = data.azurerm_subscription.subscription.subscription_id
}

output "resource_group_name" {
  value = module.az_resourcegroup.name
}

output "appservice_host_names" {
  value = module.az_appservice.host_names
}

output "shared_resourcegroup_name" {
  value = local.shared_resourcegroup_name
}