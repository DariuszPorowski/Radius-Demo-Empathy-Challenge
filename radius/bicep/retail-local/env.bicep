extension radius

@description('Azure scope used for the Radius Azure provider (resource group ID). This is required to provision the PostgreSQL database via the Azure Terraform recipe even though compute is local Kubernetes.')
param azureScope string

@description('Terraform module source for the PostgreSQL recipe. Example: git::https://github.com/<owner>/<repo>//radius/recipes/azure/postgresql-flex/terraform?ref=main')
param postgresRecipeTemplatePath string

@description('Azure location for the PostgreSQL Flexible Server (passed to the Terraform recipe).')
param postgresLocation string = 'eastus2'

@description('Demo convenience. When true, the Terraform recipe will create an allow-all firewall rule.')
param postgresAllowPublicAccess bool = true

var environmentNames = [
  'retail-dev'
  'retail-test'
  'retail-prod'
]

module env '../modules/env-kubernetes-azure.bicep' = {
  params: {
    environmentNames: environmentNames
    azureScope: azureScope
    postgresRecipeTemplatePath: postgresRecipeTemplatePath
    postgresLocation: postgresLocation
    postgresAllowPublicAccess: postgresAllowPublicAccess
  }
}
