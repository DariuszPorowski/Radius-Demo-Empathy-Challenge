using '../radius/bicep/modules/app-kubernetes.bicep'

param environment = 'retail-prod'
param kubernetesNamespace = 'retail-prod'

param image = 'ghcr.io/radius-project/samples/demo:latest'
param containerPort = 3000
