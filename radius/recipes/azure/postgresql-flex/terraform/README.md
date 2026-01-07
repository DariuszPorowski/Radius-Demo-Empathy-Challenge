# Azure PostgreSQL Flexible Server (Terraform Recipe)

This folder is a Radius Terraform Recipe template for the custom resource type:

- `Radius.Data/postgreSqlDatabases@2025-08-01-preview`

## Notes

- Radius injects a `context` variable when the recipe runs.
- This template uses `context.azure.subscription.subscriptionId` and `context.azure.resourceGroup.name` to select the Azure scope.
- It generates a cryptographically-strong password via `random_password` (not hard-coded).

## Registering

Terraform recipe templates are typically referenced as a Terraform module source with a `git::` prefix.

Example (shape only):

- `templateKind: 'terraform'`
- `templatePath: 'git::https://github.com/<org>/<repo>//radius/recipes/azure/postgresql-flex/terraform?ref=<tag-or-branch>'`
