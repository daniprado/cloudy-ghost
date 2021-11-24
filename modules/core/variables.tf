# -----------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# -----------------------------------------------------------------------------------------------
variable "location" {
  description = "Location of the components."
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

