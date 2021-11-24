# -----------------------------------------------------------------------------------------------
# Azure credentials
# -----------------------------------------------------------------------------------------------
variable "arm_tenant_id" {}
variable "arm_subscription_id" {}
variable "arm_client_id" {}
variable "arm_client_secret" {}

# -----------------------------------------------------------------------------------------------
# Deployment customization
# -----------------------------------------------------------------------------------------------
variable "ghost_version" {
  description = "Ghost app. docker image version. Must be accessible through the defined ACR."
  type        = string
}

variable "app_name" {
  description = "Name of the application. It is used in component's naming convention."
  type        = string
}

variable "organization_abv" {
  description = "Short version of the organization name. It is used in component's naming convention."
  type        = string
}

variable "primary_location" {
  description = "Name of the primary location (Azure) to be used."
  type        = string
}

variable "primary_location_abv" {
  description = "Short version of the location name. It is used in component's naming convention."
  type        = string
}

variable "cicd_resource_group" {
  description = "Name of the CICD resource group inside the given subscription."
  type        = string
}

variable "cicd_container_registry" {
  description = "Name of the ACR component to be used recovering Ghost docker image. Must be inside CICD RG."
  type        = string
}
