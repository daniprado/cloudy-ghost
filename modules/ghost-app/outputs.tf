output "web_application" {
  value = "${azurerm_app_service.ghost}"
}

output "service_plan" {
  value = "${azurerm_app_service_plan.ghost}"
}
