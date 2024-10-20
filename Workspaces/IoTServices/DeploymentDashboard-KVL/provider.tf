terraform {

  required_providers {
    azurerm = "~> 2.22"

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 1.6"
    }
  }

  backend "azurerm" {
    container_name = "terraform-state"
    key            = "terraform.tfstate"
  }

  # backend "local" {
  #   # run this to generate and view the plan in json:
  #   # terraform fmt ; terraform plan -out test.tfplan; terraform show -json test.tfplan > testplan.json
  # }
}

provider "azurerm" {
  features {}
}