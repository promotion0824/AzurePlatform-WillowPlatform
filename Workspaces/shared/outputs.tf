output subscription_id {
  value = data.azurerm_subscription.subscription.subscription_id
}

output environment {
  value = terraform.workspace
}

output diagnostics_resource_group_name {
  value = module.az_resourcegroup.name
}

output diagnostics_keyvault_name {
  value = module.az_keyvault.name
}

output shared_action_group_id {
  value = module.az_actiongroup.id
}

output diagnostics_map {
  depends_on = [
    module.az_storageaccount_diag,
    module.az_loganalytics_diag,
    module.az_eventhub_diag,
  ]

  value = "${
    map(
      "sa_id", module.az_storageaccount_diag.id,
      "la_id", module.az_loganalytics_diag.resource_id,
      "eh_id", module.az_eventhub_diag.namespace_id,
      "rg_name", module.az_resourcegroup.name,
      "sa_name", module.az_storageaccount_diag.name,
      "la_name", module.az_loganalytics_diag.name,
      "eh_name", module.az_eventhub_diag.namespace_name,
    )
  }"
}
