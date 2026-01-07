variable "context" {
  description = "Radius-provided object containing information about the resource calling the Recipe."
  type        = any
}

variable "location" {
  description = "Azure location (region) to deploy into."
  type        = string
}

variable "postgres_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "14"
}

variable "allow_public_access" {
  description = "If true, enables public network access and creates a wide-open firewall rule for demo purposes."
  type        = bool
  default     = true
}
