using '../radius/bicep/modules/app-kubernetes.bicep'

param environment = 'commercial-dev'
param kubernetesNamespace = 'commercial-dev'

param image = 'ghcr.io/radius-project/samples/demo:latest'
param containerPort = 3000
