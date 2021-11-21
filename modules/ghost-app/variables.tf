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

variable "loc" {
  description = "Short version of the location variable."
  type        = string
}

variable "acr" {
  description = "Container registry to get the initial image from."
  type        = any
}

# -----------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# -----------------------------------------------------------------------------------------------

variable "environment_name" {
  description = "Name of environment to create for the App."
  type        = string
  default     = ""
}

variable "initial_version" {
  description = "Version of the app to get from registry."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------------------------
# LOCAL VARIABLES
# -----------------------------------------------------------------------------------------------

locals {
  env           = var.environment_name != "" ? "-${var.environment_name}" : ""
  shared_name   = "ds-${var.loc}${local.env}-${var.app_name}"

  version       = var.initial_version != "" ? ":${var.initial_version}" : ""
  initial_image = "${var.acr.login_server}/${var.app_name}${local.version}"
}

