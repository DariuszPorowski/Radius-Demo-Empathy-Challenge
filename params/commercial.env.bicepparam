using '../radius/bicep/modules/env-kubernetes-azure.bicep'

param environmentNames = [
	'commercial-dev'
	'commercial-test'
	'commercial-prod'
]

param azureScope = '/subscriptions/<subId>/resourceGroups/commercial'

param postgresRecipeTemplatePath = 'git::https://github.com/<org>/<repo>//radius/recipes/azure/postgresql-flex/terraform?ref=main'
param postgresLocation = 'eastus'
param postgresAllowPublicAccess = true
