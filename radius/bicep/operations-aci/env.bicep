extension radius

@description('Azure resource group ID where ACI infrastructure/resources will be provisioned. Example: /subscriptions/<subId>/resourceGroups/<rgName>')
param aciResourceGroupId string

@description('Azure scope used for the Radius Azure provider. Typically the same resource group ID as aciResourceGroupId.')
param azureScope string = aciResourceGroupId

@description('Terraform module source for the PostgreSQL recipe. Example: git::https://github.com/<owner>/<repo>//radius/recipes/azure/postgresql-flex/terraform?ref=main')
param postgresRecipeTemplatePath string

@description('Azure location for the PostgreSQL Flexible Server (passed to the Terraform recipe).')
param postgresLocation string = 'eastus2'

@description('Demo convenience. When true, the Terraform recipe will create an allow-all firewall rule.')
param postgresAllowPublicAccess bool = true

var environmentNames = [
  'operations-dev'
  'operations-test'
  'operations-prod'
]

module env '../modules/env-aci.bicep' = {
  params: {
    environmentNames: environmentNames
    aciResourceGroupId: aciResourceGroupId
    azureScope: azureScope
    postgresRecipeTemplatePath: postgresRecipeTemplatePath
    postgresLocation: postgresLocation
    postgresAllowPublicAccess: postgresAllowPublicAccess
  }
}
