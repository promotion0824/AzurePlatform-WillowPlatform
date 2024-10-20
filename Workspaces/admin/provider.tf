provider "azurerm" {
  features {}
}

terraform {
  required_version = "~> 0.12"
  required_providers {
    azurerm = "= 2.22"
    random  = "~> 2.2"
  }

  backend "azurerm" {
    container_name = "terraform-state"
    key            = "terraform.tfstate"
  }

  # # local development
  #   backend "local" {}
}
