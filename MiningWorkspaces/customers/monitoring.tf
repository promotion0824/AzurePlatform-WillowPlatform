module "az_storageaccount_diag" {
  source              = "../../terraform-modules/azurerm/storageaccount/"
  location            = var.location
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix
  name                = "dia"
  tags                = module.az_globalvars.tags
  create_container    = var.storage_account_create_container
  container_name      = "logs"
  account_tier        = var.storage_account_tier
  replication_type    = var.storage_account_replication_type
}

module "az_loganalytics_diag" {
  source              = "../../terraform-modules/azurerm/loganalytics/"
  location            = var.location
  resource_group_name = module.az_resourcegroup.name
  resource_prefix     = module.az_globalvars.resource_prefix
  name                = "dia"
  tags                = module.az_globalvars.tags
  sku                 = var.oms_sku
  retention_in_days   = var.retention_in_days
}
