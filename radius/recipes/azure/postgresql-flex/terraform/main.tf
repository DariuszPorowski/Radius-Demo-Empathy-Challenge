locals {
  suffix = substr(md5(var.context.resource.id), 0, 16)

  // Azure PostgreSQL Flexible Server names must be 3-63 chars, lowercase alphanumeric or hyphen.
  server_name   = "pg${local.suffix}"
  database_name = "todos"

  // Map the portable resource "size" to Azure SKU/storage choices.
  // The size value comes from the resource type: var.context.resource.properties.size (S/M/L).
  // Default to S if not specified.
  size = try(var.context.resource.properties.size, "S")

  sizing = {
    S = {
      sku_name   = "B_Standard_B1ms"
      storage_mb = 32768
    }
    M = {
      sku_name   = "GP_Standard_D2s_v3"
      storage_mb = 65536
    }
    L = {
      sku_name   = "GP_Standard_D4s_v3"
      storage_mb = 131072
    }
  }

  selected = lookup(local.sizing, local.size, local.sizing.S)
}

provider "azurerm" {
  features {}

  subscription_id = var.context.azure.subscription.subscriptionId
}

resource "random_password" "admin" {
  length  = 32
  special = false
}

resource "azurerm_postgresql_flexible_server" "postgres" {
  name                = local.server_name
  resource_group_name = var.context.azure.resourceGroup.name
  location            = var.location

  sku_name   = local.selected.sku_name
  storage_mb = local.selected.storage_mb
  version    = var.postgres_version

  administrator_login    = "radiusadmin"
  administrator_password = random_password.admin.result

  public_network_access_enabled = var.allow_public_access

  tags = {
    "radius-resource-id" = var.context.resource.id
    "radius-environment" = var.context.environment.name
    "radius-application" = try(var.context.application.name, "")
  }

  lifecycle {
    prevent_destroy = false # Set to true in production to prevent accidental deletion
  }
}

resource "azurerm_postgresql_flexible_server_database" "db" {
  name      = local.database_name
  server_id = azurerm_postgresql_flexible_server.postgres.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_all" {
  count = var.allow_public_access ? 1 : 0

  name             = "allow-all"
  server_id        = azurerm_postgresql_flexible_server.postgres.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}
