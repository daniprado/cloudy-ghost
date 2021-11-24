terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.86.0"
    }
  }
}

data "azurerm_client_config" "current" {}

# -----------------------------------------------------------------------------------------------
# Resource group
# -----------------------------------------------------------------------------------------------
resource "azurerm_resource_group" "core" {
  name     = "${var.rg_name}"
  location = "${var.location}"
}

# -----------------------------------------------------------------------------------------------
# Persistence (Storage)
# -----------------------------------------------------------------------------------------------
# FIXME Add connectivity to Azure to the docker image first.
# https://github.com/hvetter-de/ghost-azurestorage
# resource "azurerm_storage_account" "storage" {
#   name                     = "sto${var.org}${var.loc}${local.env}${var.app_name}"
#   location                 = "${azurerm_resource_group.core.location}"
#   resource_group_name      = "${azurerm_resource_group.core.name}"
#   account_tier             = "Standard"
#   account_replication_type = "RA-GRS"
# }

# -----------------------------------------------------------------------------------------------
# Keyvault
# -----------------------------------------------------------------------------------------------
resource "azurerm_key_vault" "core" {
  name                = "kv-${var.shared_name}"
  location            = "${azurerm_resource_group.core.location}"
  resource_group_name = "${azurerm_resource_group.core.name}"
  tenant_id           = "${data.azurerm_client_config.current.tenant_id}"

  sku_name            = "standard"
}

resource "azurerm_key_vault_access_policy" "automation" {
  key_vault_id       = "${azurerm_key_vault.core.id}"
  tenant_id          = "${data.azurerm_client_config.current.tenant_id}"

  object_id          = "${data.azurerm_client_config.current.object_id}"

  secret_permissions = [
    "Get",
    "Set",
  ]
}

# -----------------------------------------------------------------------------------------------
# Log Analytics Workspace
# -----------------------------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "core" {
  name                = "la-${var.shared_name}"
  location            = "${azurerm_resource_group.core.location}"
  resource_group_name = "${azurerm_resource_group.core.name}"

  retention_in_days   = 30
}
