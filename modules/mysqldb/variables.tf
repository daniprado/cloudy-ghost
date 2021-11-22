# -----------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# -----------------------------------------------------------------------------------------------

variable "location" {
  description = "Location to provision the server."
  type        = string
}

variable "rg_name" {
  description = "Resource group to provision the components."
  type        = string
}

variable "server_name" {
  description = "Username for the administrator."
  type        = string
}

variable "db_name" {
  description = "Database to create."
  type        = string
}

# -----------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# -----------------------------------------------------------------------------------------------

variable "dba_name" {
  description = "User for the administrator."
  type        = string
  default     = "dsadmin"
}

variable "user_name" {
  description = "User of the database."
  type        = string
  default     = ""
}

variable "sku" {
  description = "SKU of the database server."
  type        = string
  default     = "B_Gen5_1"
}

variable "storage" {
  description = "Initial amount of MB for storing data"
  type        = number
  default     = 5120
}

# -----------------------------------------------------------------------------------------------
# LOCAL VARIABLES
# -----------------------------------------------------------------------------------------------
locals {
  user_name = var.user_name != "" ? var.user_name : var.db_name
  port      = "3306"
  ssl       = "true"
}
