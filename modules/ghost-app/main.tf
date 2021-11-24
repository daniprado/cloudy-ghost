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
resource "azurerm_resource_group" "ghost" {
  name     = "rg-${local.shared_name}"
  location = "${var.location}"
}

# -----------------------------------------------------------------------------------------------
# Persistence (Database)
# -----------------------------------------------------------------------------------------------
module "persistence" {
  source      = "../mysqldb"

  location    = "${azurerm_resource_group.ghost.location}"
  rg_name     = "${azurerm_resource_group.ghost.name}"
  server_name = "msql-${local.shared_name}"
  db_name     = "${var.app_name}"
}

# -----------------------------------------------------------------------------------------------
# Persistence (Storage)
# -----------------------------------------------------------------------------------------------
# Add this to the docker image first: https://github.com/hvetter-de/ghost-azurestorage
# resource "azurerm_storage_account" "persistence" {
#   name                     = "sto${var.org}${var.loc}${local.env}${var.app_name}"
#   location                 = "${azurerm_resource_group.ghost.location}"
#   resource_group_name      = "${azurerm_resource_group.ghost.name}"
#   account_tier             = "Standard"
#   account_replication_type = "GRS"
# }

# -----------------------------------------------------------------------------------------------
# App Service Plan
# -----------------------------------------------------------------------------------------------
resource "azurerm_app_service_plan" "ghost" {
  name                = "asp-${local.shared_name}"
  location            = "${azurerm_resource_group.ghost.location}"
  resource_group_name = "${azurerm_resource_group.ghost.name}"

  kind                = "Linux"
  reserved            = true

  sku {
    tier              = "Standard"
    size              = "S1"
  }
}

# -----------------------------------------------------------------------------------------------
# App Service
# -----------------------------------------------------------------------------------------------
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
    always_on                            = true
    ftps_state                           = "Disabled"
    health_check_path                    = "/about/"
    linux_fx_version                     = "DOCKER|${local.initial_image}"
  }

  # Debuging purposes
  logs {
    http_logs {
      file_system {
        retention_in_days = 2
        retention_in_mb   = 25
      }
    }
  }

  app_settings = {
    # Ghost params
    "database__client"                                = "${module.persistence.server_type}"
    "database__connection__host"                      = "${module.persistence.server_fqdn}"
    "database__connection__database"                  = "${module.persistence.database_name}"
    "database__connection__user"                      = "${module.persistence.user_name}"
    "database__connection__password"                  = "@Microsoft.KeyVault(SecretUri=${local.dbconnpwd})"
    "database__connection__port"                      = "${module.persistence.server_port}"
    "database__connection__ssl"                       = "${module.persistence.server_ssl}"
    "url"                                             = "https://as-${local.shared_name}.azurewebsites.net"

    "WEBSITES_ENABLE_APP_SERVICE_STORAGE"             = "false"

    # Application insights...
    "APPINSIGHTS_INSTRUMENTATIONKEY"                  = "${azurerm_application_insights.ghost.instrumentation_key}"
    "APPLICATIONINSIGHTS_CONNECTION_STRING"           = "${azurerm_application_insights.ghost.connection_string}"
    "APPINSIGHTS_PROFILERFEATURE_VERSION"             = "1.0.0"
    "APPINSIGHTS_SNAPSHOTFEATURE_VERSION"             = "1.0.0"
    "APPLICATIONINSIGHTS_CONFIGURATION_CONTENT"       = ""
    "ApplicationInsightsAgent_EXTENSION_VERSION"      = "~3"
    "DiagnosticServices_EXTENSION_VERSION"            = "~3"
    "InstrumentationEngine_EXTENSION_VERSION"         = "disabled"
    "SnapshotDebugger_EXTENSION_VERSION"              = "disabled"
    "XDT_MicrosoftApplicationInsights_BaseExtensions" = "disabled"
    "XDT_MicrosoftApplicationInsights_Mode"           = "recommended"
    "XDT_MicrosoftApplicationInsights_PreemptSdk"     = "disabled"
  }
}

locals {
  dbconnpwd = "${azurerm_key_vault.ghost.vault_uri}secrets/${azurerm_key_vault_secret.dbupwd.name}/${azurerm_key_vault_secret.dbupwd.version}"
}

resource "azurerm_role_assignment" "appserv" {
  principal_id         = "${azurerm_app_service.ghost.identity.0.principal_id}"
  scope                = "${var.acr.id}"
  role_definition_name = "acrpull"
}

# -----------------------------------------------------------------------------------------------
# Keyvault
# -----------------------------------------------------------------------------------------------
resource "azurerm_key_vault" "ghost" {
  name                 = "kv-${local.shared_name}"
  location             = "${azurerm_resource_group.ghost.location}"
  resource_group_name  = "${azurerm_resource_group.ghost.name}"
  tenant_id            = "${data.azurerm_client_config.current.tenant_id}"

  sku_name             = "standard"
}

resource "azurerm_key_vault_access_policy" "automation" {
  key_vault_id       = "${azurerm_key_vault.ghost.id}"
  tenant_id          = "${data.azurerm_client_config.current.tenant_id}"

  object_id          = "${data.azurerm_client_config.current.object_id}"

  secret_permissions = [
    "Get",
    "Set",
  ]
}

resource "azurerm_key_vault_access_policy" "appserv" {
  key_vault_id       = "${azurerm_key_vault.ghost.id}"
  tenant_id          = "${data.azurerm_client_config.current.tenant_id}"

  object_id          = "${azurerm_app_service.ghost.identity.0.principal_id}"

  secret_permissions = [ 
    "Get",
  ]
}

# -----------------------------------------------------------------------------------------------
# Keyvault secrets
# -----------------------------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "dbapwd" {
  key_vault_id = "${azurerm_key_vault.ghost.id}"

  name         = "mysql-ghost-dba-pwd"
  value        = "${module.persistence.dba_password}"

  # Adding secrets won't work without "automation" policy
  depends_on   = [azurerm_key_vault_access_policy.automation]
}

resource "azurerm_key_vault_secret" "dbupwd" {
  key_vault_id = "${azurerm_key_vault.ghost.id}"

  name         = "mysql-ghost-user-pwd"
  value        = "${module.persistence.user_password}"

  # Adding secrets won't work without "automation" policy
  depends_on   = [azurerm_key_vault_access_policy.automation]
}

# -----------------------------------------------------------------------------------------------
# App Insights
# -----------------------------------------------------------------------------------------------
resource "azurerm_application_insights" "ghost" {
  name                = "ai-${local.shared_name}"
  location            = "${azurerm_resource_group.ghost.location}"
  resource_group_name = "${azurerm_resource_group.ghost.name}"

  application_type    = "web"
}

# -----------------------------------------------------------------------------------------------
# Log Analytics Workspace
# -----------------------------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "ghost" {
  name                = "la-${local.shared_name}"
  location            = "${azurerm_resource_group.ghost.location}"
  resource_group_name = "${azurerm_resource_group.ghost.name}"

  retention_in_days   = 30
}

# -----------------------------------------------------------------------------------------------
# Diagnostic settings
# -----------------------------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "persistence" {
  name                           = "persistence_metrics"
  target_resource_id             = module.persistence.server_id
  log_analytics_workspace_id     = "${azurerm_log_analytics_workspace.ghost.id}"
  log_analytics_destination_type = "Dedicated"

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "servplan" {
  name                           = "serviceplan_metrics"
  target_resource_id             = "${azurerm_app_service_plan.ghost.id}"
  log_analytics_workspace_id     = "${azurerm_log_analytics_workspace.ghost.id}"
  log_analytics_destination_type = "Dedicated"

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }
}

# -----------------------------------------------------------------------------------------------
# Autoscale settings
# -----------------------------------------------------------------------------------------------
resource "azurerm_monitor_autoscale_setting" "servplan" {
  name                = "http_queue_length"
  location            = "${azurerm_resource_group.ghost.location}"
  resource_group_name = "${azurerm_resource_group.ghost.name}"
  target_resource_id  = "${azurerm_app_service_plan.ghost.id}"

  profile {
    name = "defaultProfile"

    capacity {
      default = 1
      minimum = 1
      maximum = 10
    }

    rule {
      metric_trigger {
        metric_name              = "HttpQueueLength"
        metric_resource_id       = "${azurerm_app_service_plan.ghost.id}"
        time_grain               = "PT1M"
        statistic                = "Average"
        time_window              = "PT5M"
        time_aggregation         = "Average"
        operator                 = "GreaterThan"
        threshold                = 50
        divide_by_instance_count = true
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name              = "HttpQueueLength"
        metric_resource_id       = "${azurerm_app_service_plan.ghost.id}"
        time_grain               = "PT1M"
        statistic                = "Average"
        time_window              = "PT5M"
        time_aggregation         = "Average"
        operator                 = "LessThan"
        threshold                = 5
        divide_by_instance_count = true
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = true
      send_to_subscription_co_administrator = true
    }
  }
}
