terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.86.0"
    }
  }
}

# -----------------------------------------------------------------------------------------------
# MySQL Server
# -----------------------------------------------------------------------------------------------
# TODO Should be replaced by a Zone-redundant Flexible Server to achieve cross-region high availability
# https://docs.microsoft.com/en-us/azure/mysql/flexible-server/concepts-high-availability
resource "azurerm_mysql_server" "db" {
  name                         = "${var.server_name}"
  location                     = "${var.location}"
  resource_group_name          = "${var.rg_name}"

  administrator_login          = "${var.dba_name}"
  administrator_login_password = "${random_password.dbapwd.result}"

  sku_name                     = "${var.sku}"
  storage_mb                   = "${var.storage}"
  version                      = "5.7"
  ssl_enforcement_enabled      = true
}

resource "random_password" "dbapwd" {
  length      = 17
  special     = false
  number      = true
  min_lower   = 1
  min_upper   = 1
  min_numeric = 1
}

# -----------------------------------------------------------------------------------------------
# Firewall rules
# -----------------------------------------------------------------------------------------------
# TODO Should be replaced by VNet/NSG setup in the Flexible Server scenario...
# FIXME ...even in the current implemented scenario a specific set of IP-whitelisting rules pointing
# to the Service Plan is better than this approach, but "dirtier" and harder to maintain.
resource "azurerm_mysql_firewall_rule" "azserv" {
  name                = "azure-services"
  resource_group_name = "${azurerm_mysql_server.db.resource_group_name}"
  server_name         = "${azurerm_mysql_server.db.name}"
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

# FIXME Develop purposes (should point to the machine runing Terraform)
resource "azurerm_mysql_firewall_rule" "allopen" {
  name                = "REMOVE_ASAP"
  resource_group_name = "${azurerm_mysql_server.db.resource_group_name}"
  server_name         = "${azurerm_mysql_server.db.name}"
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "255.255.255.255"
}

# -----------------------------------------------------------------------------------------------
# MySQL Database
# -----------------------------------------------------------------------------------------------
# FIXME A specific user with ALL privileges to this specific DB should be created
resource "azurerm_mysql_database" "db" {
  name                = "${var.db_name}"
  resource_group_name = "${azurerm_mysql_server.db.resource_group_name}"
  server_name         = "${azurerm_mysql_server.db.name}"
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

# -----------------------------------------------------------------------------------------------
# Keyvault secrets
# -----------------------------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "dbaname" {
  key_vault_id = "${var.key_vault.id}"

  name         = "mysql-${var.db_name}-dba-user"
  value        = "${var.dba_name}@${azurerm_mysql_server.db.name}"
}

resource "azurerm_key_vault_secret" "dbapwd" {
  key_vault_id = "${var.key_vault.id}"

  name         = "mysql-${var.db_name}-dba-pwd"
  value        = "${random_password.dbapwd.result}"
}

# -----------------------------------------------------------------------------------------------
# Diagnostic settings
# -----------------------------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "persistence" {
  name                           = "persistence_metrics"
  target_resource_id             = "${azurerm_mysql_server.db.id}"
  log_analytics_workspace_id     = "${var.log_analytics.id}"
  log_analytics_destination_type = "Dedicated"

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }
}
