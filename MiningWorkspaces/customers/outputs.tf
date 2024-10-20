output subscription_id {
  value = data.azurerm_subscription.subscription.subscription_id
}

output resource_group_name {
  value = module.az_resourcegroup.name
}

output "shared_resourcegroup_name" {
  value = local.shared_resourcegroup_name
}