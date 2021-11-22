output "server_id" {
  value = "${azurerm_mysql_server.db.id}"
}

output "server_name" {
  value = "${azurerm_mysql_server.db.id}"
}

output "server_fqdn" {
  value = "${azurerm_mysql_server.db.fqdn}"
}

output "server_type" {
  value = "mysql"
}

output "server_port" {
  value = "${local.port}"
}

output "server_ssl" {
  value = "${local.ssl}"
}

output "database_name" {
  value = "${azurerm_mysql_server.db.name}"
}

output "dba_name" {
  value = "${var.dba_name}@${azurerm_mysql_server.db.name}"
}

output "dba_password" {
  value     = "${random_password.dbapwd.result}"
  sensitive = true
}

# FIXME A specific user should be created
output "user_name" {
  value = "${var.dba_name}@${azurerm_mysql_server.db.name}"
}

# FIXME A specific user should be created
output "user_password" {
  value     = "${random_password.dbapwd.result}"
  sensitive = true
}
