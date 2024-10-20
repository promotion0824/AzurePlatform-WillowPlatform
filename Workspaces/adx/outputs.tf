output subscription_id {
  value = data.azurerm_subscription.subscription.subscription_id
}

output resource_group_name {
  value = data.azurerm_resource_group.customer_rsg.name
}

output unified_event_hub_namespace_name {
  value = module.az_unified_eventhub.namespace_name
}

output external_event_hub_namespace_name {
  value = data.azurerm_eventhub_namespace.saj.name
}
