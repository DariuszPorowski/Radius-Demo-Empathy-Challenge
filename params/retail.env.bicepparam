using '../radius/bicep/modules/env-kubernetes-azure.bicep'

param environmentNames = [
	'retail-dev'
	'retail-test'
	'retail-prod'
]

param azureScope = '/subscriptions/<subId>/resourceGroups/retail'

param postgresRecipeTemplatePath = 'git::https://github.com/<org>/<repo>//radius/recipes/azure/postgresql-flex/terraform?ref=main'
param postgresLocation = 'eastus'
param postgresAllowPublicAccess = true
