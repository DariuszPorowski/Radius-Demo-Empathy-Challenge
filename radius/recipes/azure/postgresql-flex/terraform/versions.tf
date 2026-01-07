terraform {
  required_version = ">= 1.14.3"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.57"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.7"
    }
  }
}
