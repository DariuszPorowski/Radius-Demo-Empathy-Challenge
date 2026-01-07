extension radius

@description('Array of Radius environment names to create (e.g. [\'commercial-dev\', \'commercial-test\']).')
param environmentNames string[]

@description('Azure scope used for the Radius Azure provider (resource group ID). Example: /subscriptions/<subId>/resourceGroups/<rgName>')
param azureScope string

@description('Terraform module source for the PostgreSQL recipe. Example: git::https://github.com/<owner>/<repo>//radius/recipes/azure/postgresql-flex/terraform?ref=main')
param postgresRecipeTemplatePath string

@description('Azure location for the PostgreSQL Flexible Server (passed to the Terraform recipe).')
param postgresLocation string = 'eastus'

@description('Demo convenience. When true, the Terraform recipe will create an allow-all firewall rule.')
param postgresAllowPublicAccess bool = true

resource envs 'Applications.Core/environments@2023-10-01-preview' = [for envName in environmentNames: {
  name: envName
  location: 'global'
  properties: {
    compute: {
      kind: 'kubernetes'
      resourceId: 'self'
      namespace: envName
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
