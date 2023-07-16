### GLOBAL ###

variable "environment" {
  type        = string
  description = "Environment type for this deployment."

  default = "local"

  validation {
    condition     = (var.environment == "production" || var.environment == "prodmirror" || var.environment == "dev" || var.environment == "local")
    error_message = "Environment must be one of [production - prodmirror - dev]."
  }
}

variable "project_name" {
  type        = string
  description = "Name of the project."

  validation {
    condition = (
      can(regex("^[a-z]+(-[a-z]+)*$", var.project_name))
      && 3 <= length(var.project_name) && length(var.project_name) <= 16
    )
    error_message = "The name must be dash delimited words composed of lowercase letters."
  }
}

variable "team_name" {
  type        = string
  description = "Name of the team."

  validation {
    condition = (
      can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.team_name))
      && 3 <= length(var.team_name) && length(var.team_name) <= 16
    )
    error_message = "The name must be dash delimited words composed of lowercase letters."
  }
}

variable "week" {
  type        = string
  description = "Week number"

  validation {
    condition     = can(regex("^[a-z]+[0-9]+$", var.week))
    error_message = "The name must be a string followed by a number."
  }
}

variable "zone" {
  type        = string
  description = "Availability for this deployment."

  default = "us-east-1a"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.zone))
    error_message = "The name must be a string consisting of lowercase letters, dashes, and numbers."
  }
}

locals {
  environment  = var.environment != "local" ? var.environment : terraform.workspace
  project_name = var.project_name
  team_name    = var.team_name
  week         = var.week
  zone         = var.zone

  # Get Credentials
  service_account = jsondecode(file("SA_credentials.json"))

  global_identifier  = "${var.team_name}-${var.project_name}-${local.environment}"
  is_critical_string = local.environment == "production" ? "YES" : "NO"
}