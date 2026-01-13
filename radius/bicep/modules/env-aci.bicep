extension radius

@description('Array of Radius environment names to create (e.g. [\'operations-dev\', \'operations-test\']).')
param environmentNames string[]

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

resource envs 'Applications.Core/environments@2023-10-01-preview' = [for envName in environmentNames: {
  name: envName
  location: 'global'
  properties: {
    compute: {
      kind: 'aci'
      resourceGroup: aciResourceGroupId
      // ACI requires a managed identity; if not provided for kind=aci, Radius defaults to systemAssigned.
      identity: {
        kind: 'systemAssigned'
      }
    }
    recipes: {
      'Radius.Data/postgreSqlDatabases': {
        default: {
          templateKind: 'terraform'
          templatePath: postgresRecipeTemplatePath
          parameters: {
            location: postgresLocation
            allow_public_access: postgresAllowPublicAccess
          }
        }
      }
    }
    providers: {
      azure: {
        scope: azureScope
      }
    }
  }
}]
