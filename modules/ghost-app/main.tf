terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.86.0"
    }
  }
}

data "azurerm_client_config" "current" {}

# Resource group
resource "azurerm_resource_group" "ghost" {
  name     = "rg-${local.shared_name}"
  location = "${var.location}"
}

# Keyvault
resource "azurerm_key_vault" "ghost" {
  name                 = "kv-${local.shared_name}"
  location             = "${azurerm_resource_group.ghost.location}"
  resource_group_name  = "${azurerm_resource_group.ghost.name}"
  tenant_id            = "${data.azurerm_client_config.current.tenant_id}"

  sku_name                        = "standard"
  enabled_for_template_deployment = true
}

/* resource "azurerm_key_vault_access_policy" "automation" { */
/*   key_vault_id       = "${azurerm_key_vault.ghost.id}" */
/*   tenant_id          = "${data.azurerm_client_config.current.tenant_id}" */

/*   object_id          = "${data.azurerm_client_config.current.object_id}" */

/*   secret_permissions = [ */
/*     "Get", */
/*     "Set", */
/*   ] */
/* } */

resource "azurerm_key_vault_access_policy" "appserv" {
  key_vault_id       = "${azurerm_key_vault.ghost.id}"
  tenant_id          = "${data.azurerm_client_config.current.tenant_id}"

  object_id          = "${azurerm_app_service.ghost.identity.0.principal_id}"

  secret_permissions = [ 
    "Get",
  ]
}

resource "azurerm_key_vault_secret" "dbupwd" {
  key_vault_id = "${azurerm_key_vault.ghost.id}"

  name         = "mysql-ghost-user-pwd"
  value        = "${module.persistence.dbupwd}"

  depends_on = [azurerm_key_vault_access_policy.automation]
}

# MySQL Database
module "persistence" {
  source = "../mysqldb"

  location    = "${azurerm_resource_group.ghost.location}"
  rg_name     = "${azurerm_resource_group.ghost.name}"
  server_name = "msql-${local.shared_name}"
  db_name     = "${var.app_name}"
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "ghost" {
  name                = "la-${local.shared_name}"
  location            = "${azurerm_resource_group.ghost.location}"
  resource_group_name = "${azurerm_resource_group.ghost.name}"

  retention_in_days   = 30
}

# App Insights
resource "azurerm_application_insights" "ghost" {
  name                = "ai-${local.shared_name}"
  location            = "${azurerm_resource_group.ghost.location}"
  resource_group_name = "${azurerm_resource_group.ghost.name}"

  application_type    = "web"
}

# App Service Plan
resource "azurerm_app_service_plan" "ghost" {
  name                = "asp-${local.shared_name}"
  location            = "${azurerm_resource_group.ghost.location}"
  resource_group_name = "${azurerm_resource_group.ghost.name}"

  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_role_assignment" "appserv" {
  principal_id         = "${azurerm_app_service.ghost.identity.0.principal_id}"
  scope                = "${var.acr.id}"
  role_definition_name = "acrpull"
}

locals {
  dbconnpwd = "${azurerm_key_vault.ghost.vault_uri}secrets/${azurerm_key_vault_secret.dbupwd.name}/${azurerm_key_vault_secret.dbupwd.version}"
}

# App Service
resource "azurerm_app_service" "ghost" {
  name                = "as-${local.shared_name}"
  location            = "${azurerm_resource_group.ghost.location}"
  resource_group_name = "${azurerm_resource_group.ghost.name}"
  app_service_plan_id = "${azurerm_app_service_plan.ghost.id}"

  https_only          = true

  identity {
    type              = "SystemAssigned"
  }
  site_config {
    acr_use_managed_identity_credentials = true
    health_check_path                    = "/index.html"
    linux_fx_version                     = "DOCKER|${local.initial_image}"
  }
  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY"      = "${azurerm_application_insights.ghost.instrumentation_key}"
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
    "WEBSITE_HTTPLOGGING_RETENTION_DAYS"  = "2" # Debuging purposes
    "database__client"                    = "${module.persistence.type}"
    "database__connection__host"          = "${module.persistence.fqdn}"
    "database__connection__database"      = "${module.persistence.dbname}"
    "database__connection__user"          = "${module.persistence.dbuname}"
    "database__connection__password"      = "@Microsoft.KeyVault(SecretUri=${local.dbconnpwd})"
    "database__connection__port"          = "${module.persistence.port}"
    "database__connection__ssl"           = "${module.persistence.ssl}"
    "url"                                 = "https://as-${local.shared_name}.azurewebsites.net"
  }
}

