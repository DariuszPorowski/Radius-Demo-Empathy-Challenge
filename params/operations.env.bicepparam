using '../radius/bicep/modules/env-aci.bicep'

param environmentNames = [
	'operations-dev'
	'operations-test'
	'operations-prod'
]

param aciResourceGroupId = '/subscriptions/<subId>/resourceGroups/operations'
param azureScope = '/subscriptions/<subId>/resourceGroups/operations'

param postgresRecipeTemplatePath = 'git::https://github.com/<org>/<repo>//radius/recipes/azure/postgresql-flex/terraform?ref=main'
param postgresLocation = 'eastus'
param postgresAllowPublicAccess = true
