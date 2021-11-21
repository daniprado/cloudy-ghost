terraform {
  required_version = "=1.0.10"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.86.0"
    }
  }
  backend "azurerm" {
      resource_group_name  = "rg-ds-weu-cicd04"
      storage_account_name = "stodsweucicd04"
      container_name       = "tfstate"
      key                  = "cloudy-ghost.tfstate"
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_container_registry" "cicd" {
  name                 = "crdsweucicd04"
  resource_group_name  = "rg-ds-weu-cicd04"
}

module "cloudy-ghost" {
  source = "./modules/ghost-app"

  app_name = "ghost"
  location = "westeurope"
  loc      = "weu"

  acr             = "${data.azurerm_container_registry.cicd}"
  initial_version = "4.22.3"

}
