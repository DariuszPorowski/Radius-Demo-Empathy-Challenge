using '../radius/bicep/modules/app-kubernetes.bicep'

param environment = 'retail-dev'
param kubernetesNamespace = 'retail-dev'

param image = 'ghcr.io/radius-project/samples/demo:latest'
param containerPort = 3000
