provider "azurerm" {
  features {}
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.5"
    }
    azuread = "~> 2.22"
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
