extension radius

@description('The Radius environment to deploy to (e.g. commercial-dev).')
param environment string = 'commercial-dev'

@description('Container image for the Todo app.')
param image string = 'ghcr.io/radius-project/samples/demo:latest'

@description('Port the Todo app listens on inside the container.')
param containerPort int = 3000

module app '../modules/app-kubernetes.bicep' = {
  params: {
    environment: environment
    image: image
    containerPort: containerPort
  }
}
