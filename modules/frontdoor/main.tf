terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.86.0"
    }
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_frontdoor" "fd" {
  name                                         = "fd-${var.shared_name}"
  resource_group_name                          = "${var.rg_name}"
  enforce_backend_pools_certificate_name_check = false

  routing_rule {
    name               = "${var.app_name}-routing-rule"
    accepted_protocols = ["Http", "Https"]
    patterns_to_match  = ["/*"]
    frontend_endpoints = ["fd-${var.shared_name}-frontend"]
    forwarding_configuration {
      forwarding_protocol = "MatchRequest"
      backend_pool_name   = "${var.app_name}-backend-pool"
    }
  }

  backend_pool {
    name     = "${var.app_name}-backend-pool"

    backend {
      host_header = "${var.primary_web_application.default_site_hostname}"
      address     = "${var.primary_web_application.default_site_hostname}"
      http_port   = 80
      https_port  = 443

      priority    = 1
    }

    backend {
      host_header = "${var.secondary_web_application.default_site_hostname}"
      address     = "${var.secondary_web_application.default_site_hostname}"
      http_port   = 80
      https_port  = 443

      priority    = 5
    }

    load_balancing_name = "${var.app_name}-load-balancing"
    health_probe_name   = "${var.app_name}-health-probe"
  }

  backend_pool_load_balancing {
    name = "${var.app_name}-load-balancing"
  }

  backend_pool_health_probe {
    name = "${var.app_name}-health-probe"
  }

  frontend_endpoint {
    name                     = "fd-${var.shared_name}-frontend"
    host_name                = "fd-${var.shared_name}.azurefd.net"
    session_affinity_enabled = true
  }
}
