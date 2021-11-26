# -----------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# -----------------------------------------------------------------------------------------------
variable "app_name" {
  description = "Name of the application."
  type        = string
}

variable "location" {
  description = "Location of the components."
  type        = string
}

variable "shared_name" {
  description = "Common part of name for all components to be created."
  type        = string
}

variable "container_registry" {
  description = "Container registry to get the initial image from."
}

variable "db" {
  description = "DB module to connect as persistence."
}

variable "key_vault" {
  description = "Keyvault component to connect as secrets provider."
}

variable "log_analytics" {
  description = "Log Analytics workspace component to provide telemetry data."
}

# -----------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# -----------------------------------------------------------------------------------------------
variable "app_image" {
  description = "Docker image of the app to get from registry."
  type        = string
  default     = "ghost"
}

variable "app_version" {
  description = "Version of the app to get from registry."
  type        = string
  default     = "latest"
}

