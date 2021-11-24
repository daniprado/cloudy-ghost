output "location" {
  value = var.location
}

output "resource_group" {
  value = azurerm_resource_group.core
}

output "key_vault" {
  value = azurerm_key_vault.core
}

output "log_analytics" {
  value = azurerm_log_analytics_workspace.core
}

