output subscription_id {
  value = data.azurerm_subscription.subscription.subscription_id
}

output resource_group_name {
  value = local.resource_group_name
}
