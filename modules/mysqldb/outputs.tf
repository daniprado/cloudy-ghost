output "type" {
  value = "mysql"
}

output "fqdn" {
  value = "${azurerm_mysql_server.db.fqdn}"
}

output "port" {
  value = "${local.port}"
}

output "ssl" {
  value = "${local.ssl}"
}

output "dbname" {
  value = "${azurerm_mysql_server.db.name}"
}

output "dbaname" {
  value = "${var.dba_name}@${azurerm_mysql_server.db.name}"
}

output "dbapwd" {
  value     = "${random_password.dbapwd.result}"
  sensitive = true
}

output "dbuname" {
  value = "${mysql_user.dbu.user}@${azurerm_mysql_server.db.name}"
}

output "dbupwd" {
  value     = "${random_password.dbupwd.result}"
  sensitive = true
}
