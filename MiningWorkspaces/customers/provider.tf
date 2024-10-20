provider "azurerm" {
  features {}
}

provider "azurerm" {
  alias           = "adx"
  subscription_id = var.adx_cluster_subscription_id
  features {}
}

terraform {
  required_version = "~> 0.12"
  required_providers {
    azurerm = "= 2.22"
    azuread = "~> 0.7"
    random  = "~> 2.2"
    null    = "~> 2.1"
  }

  backend "azurerm" {
    container_name = "terraform-state"
    key            = "terraform.tfstate"
  }

  #   # local development
  #   backend "local" {}
}
