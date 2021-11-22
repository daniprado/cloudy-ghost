terraform {
  required_version = "=1.0.10"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.86.0"
    }
  }
  backend "azurerm" {
      resource_group_name  = "${var.cicd_resource_group}"
      storage_account_name = "${var.cicd_storage_account}"
      container_name       = "${var.cicd_tfstate_blob}"
      key                  = "${var.app_name}.tfstate"
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_container_registry" "cicd" {
  name                = "${var.cicd_container_registry}"
  resource_group_name = "${var.cicd_resource_group}"
}

module "cloudy-ghost" {
  source          = "./modules/ghost-app"

  app_name        = "${var.app_name}"
  location        = "${var.primary_location}"
  loc             = "${var.primary_location_abv}"
  org             = "${var.organization_abv}"

  acr             = "${data.azurerm_container_registry.cicd}"
  initial_version = "${var.ghost_version}"

}
