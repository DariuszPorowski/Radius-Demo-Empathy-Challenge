using '../radius/bicep/modules/app-kubernetes.bicep'

param environment = 'commercial-test'
param kubernetesNamespace = 'commercial-test'

param image = 'ghcr.io/radius-project/samples/demo:latest'
param containerPort = 3000
