output "server_name" {
  value = "${azurerm_mysql_server.db.name}"
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
  value = "${azurerm_key_vault_secret.dbaname}"
}

output "dba_password" {
  value = "${azurerm_key_vault_secret.dbapwd}"
}

# FIXME A specific user should be created
output "user_name" {
  value = "${azurerm_key_vault_secret.dbaname}"
}

output "user_password" {
  value = "${azurerm_key_vault_secret.dbapwd}"
}
