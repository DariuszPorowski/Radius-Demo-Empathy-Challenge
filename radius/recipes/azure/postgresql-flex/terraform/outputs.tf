output "result" {
  // Radius requires a "result" output containing:
  // - "values": non-secret fields that match the target resource type's read-only properties.
  // - "secrets": secret fields that match the target resource type's read-only properties.
  // - "resources": IDs of the backing resources (for dependency tracking).
  value = {
    values = {
      host     = azurerm_postgresql_flexible_server.postgres.fqdn
      port     = 5432
      database = azurerm_postgresql_flexible_server_database.db.name
      username = azurerm_postgresql_flexible_server.postgres.administrator_login
    }

    secrets = {
      password = random_password.admin.result
    }

    resources = [
      azurerm_postgresql_flexible_server.postgres.id,
      azurerm_postgresql_flexible_server_database.db.id
    ]
  }

  sensitive = true
}
