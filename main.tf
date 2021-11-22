terraform {
  required_version = "=1.0.10"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.86.0"
    }
  }
  backend "azurerm" {
      resource_group_name  = "$CICD_RESOURCE_GROUP"
      storage_account_name = "$CICD_STORAGE_ACCOUNT"
      container_name       = "$CICD_TFSTATE_BLOB"
      key                  = "$APP_NAME.tfstate"
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_container_registry" "cicd" {
  name                 = "$CICD_CONTAINER_REGISTRY"
  resource_group_name  = "$CICD_RESOURCE_GROUP"
}

module "cloudy-ghost" {
  source = "./modules/ghost-app"

  app_name = "$APP_NAME"
  location = "$PRIMARY_LOCATION"
  loc      = "$PRIMARY_LOCATION_ABV"

  acr             = "${data.azurerm_container_registry.cicd}"
  initial_version = "$GHOST_VERSION"

}
