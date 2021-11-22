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

resource "azurerm_mysql_server" "db" {
  name                         = "${var.server_name}"
  location                     = "${var.location}"
  resource_group_name          = "${var.rg_name}"

  administrator_login          = "${var.dba_name}"
  administrator_login_password = "${random_password.dbapwd.result}"

  sku_name                     = "${var.sku}"
  storage_mb                   = "${var.storage}"
  version                      = "8.0"
  ssl_enforcement_enabled      = true
}

resource "random_password" "dbapwd" {
  length  = 17
  special = false
}

# -----------------------------------------------------------------------------------------------
# Firewall rules
# -----------------------------------------------------------------------------------------------

resource "azurerm_mysql_firewall_rule" "azserv" {
  name                = "azure-services"
  resource_group_name = "${azurerm_mysql_server.db.resource_group_name}"
  server_name         = "${azurerm_mysql_server.db.name}"
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

# Develop purposes (should point to the machine runing Terraform)
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
resource "azurerm_mysql_database" "db" {
  name                = "${var.db_name}"
  resource_group_name = "${azurerm_mysql_server.db.resource_group_name}"
  server_name         = "${azurerm_mysql_server.db.name}"
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

