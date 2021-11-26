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
  name     = "rg-${var.shared_name}"
  location = "${var.location}"
}

# -----------------------------------------------------------------------------------------------
# App Service Plan
# -----------------------------------------------------------------------------------------------
resource "azurerm_app_service_plan" "ghost" {
  name                = "asp-${var.shared_name}"
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
locals {
  app_component_name = "as-${var.shared_name}"

  db_user             = "${var.key_vault.vault_uri}secrets/${var.db.user_name.name}/${var.db.user_name.version}"
  db_pwd              = "${var.key_vault.vault_uri}secrets/${var.db.user_password.name}/${var.db.user_password.version}"

  app_image           = "${var.container_registry.login_server}/${var.app_image}:${var.app_version}"
}

resource "azurerm_app_service" "ghost" {
  name                = "${local.app_component_name}"
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
    linux_fx_version                     = "DOCKER|${local.app_image}"
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
    "database__client"                                = "${var.db.server_type}"
    "database__connection__host"                      = "${var.db.server_fqdn}"
    "database__connection__database"                  = "${var.db.database_name}"
    "database__connection__user"                      = "@Microsoft.KeyVault(SecretUri=${local.db_user})"
    "database__connection__password"                  = "@Microsoft.KeyVault(SecretUri=${local.db_pwd})"
    "database__connection__port"                      = "${var.db.server_port}"
    "database__connection__ssl"                       = "${var.db.server_ssl}"
    "url"                                             = "https://${local.app_component_name}.azurewebsites.net"

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

resource "azurerm_role_assignment" "appserv" {
  principal_id         = "${azurerm_app_service.ghost.identity.0.principal_id}"
  scope                = "${var.container_registry.id}"
  role_definition_name = "acrpull"
}

# -----------------------------------------------------------------------------------------------
# KeyVault access policies
# -----------------------------------------------------------------------------------------------
resource "azurerm_key_vault_access_policy" "appserv" {
  key_vault_id       = "${var.key_vault.id}"
  tenant_id          = "${data.azurerm_client_config.current.tenant_id}"

  object_id          = "${azurerm_app_service.ghost.identity.0.principal_id}"

  secret_permissions = [
    "Get",
  ]
}

# -----------------------------------------------------------------------------------------------
# App Insights
# -----------------------------------------------------------------------------------------------
resource "azurerm_application_insights" "ghost" {
  name                = "ai-${var.shared_name}"
  location            = "${azurerm_resource_group.ghost.location}"
  resource_group_name = "${azurerm_resource_group.ghost.name}"

  application_type    = "web"
}


# -----------------------------------------------------------------------------------------------
# Diagnostic settings
# -----------------------------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "servplan" {
  name                           = "serviceplan_metrics"
  target_resource_id             = "${azurerm_app_service_plan.ghost.id}"
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
