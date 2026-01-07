using '../radius/bicep/modules/app-kubernetes.bicep'

param environment = 'commercial-prod'
param kubernetesNamespace = 'commercial-prod'

param image = 'ghcr.io/radius-project/samples/demo:latest'
param containerPort = 3000
