# -----------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# -----------------------------------------------------------------------------------------------
variable "app_name" {
  description = "Name of the application."
  type        = string
}

variable "shared_name" {
  description = "Common part of name for all components to be created."
  type        = string
}

variable "rg_name" {
  description = "Resource group to provision the components."
  type        = string
}

variable "primary_web_application" {
  description = "Primary backend to use."
}

variable "secondary_web_application" {
  description = "Secondary backend to use."
}

