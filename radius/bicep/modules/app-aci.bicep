extension radius

@description('The Radius environment to deploy to (e.g. operations-dev).')
param environment string

@description('Container image for the Todo app.')
param image string = 'ghcr.io/radius-project/samples/demo:latest'

@description('Port the Todo app listens on inside the container.')
param containerPort int = 3000

resource app 'Applications.Core/applications@2023-10-01-preview' = {
  name: 'todo-app'
  location: 'global'
  properties: {
    environment: environment
  }
}

resource db 'Radius.Data/postgreSqlDatabases@2025-08-01-preview' = {
  name: 'postgres'
  location: 'global'
  properties: {
    application: app.id
    environment: environment
  }
}

resource gateway 'Applications.Core/gateways@2023-10-01-preview' = {
  name: 'gateway'
  location: 'global'
  properties: {
    application: app.id
    routes: [
      {
        path: '/'
        destination: 'http://todo:${containerPort}'
      }
    ]
  }
}

resource todo 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'todo'
  location: 'global'
  properties: {
    application: app.id
    container: {
      image: image
      ports: {
        web: {
          containerPort: containerPort
        }
      }
    }
    connections: {
      postgresql: {
        source: db.id
      }
    }
    runtimes: {
      aci: {
        gatewayID: gateway.id
      }
    }
  }
}
