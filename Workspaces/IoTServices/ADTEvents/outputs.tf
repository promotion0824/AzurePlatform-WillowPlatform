output "digital_twin_name" {
  value = data.azurerm_digital_twins_instance.adt_instance.name
}

output "endpoint_name" {
  value = azurerm_digital_twins_endpoint_eventhub.adt_eventhub_endpoint.name
}