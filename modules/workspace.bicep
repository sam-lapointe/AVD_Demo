@description('The name of the workspace.')
param name string = 'Workspace-General'

@description('The description of this workspace')
param wsDescription string = 'General Workspace.'

@description('Location of the workspace.')
param location string 

param tags object

@description('True to enable diagnostics for the Azure Virtual Deskop resources.')
param enableDiagnostics bool

@description('The application group to add to the workspace.')
param applicationGroupID string

param diagnosticWorkspaceID string

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2023-09-05' = {
  name: name
  location: location
  tags: tags
  properties: {
    description: wsDescription
    applicationGroupReferences: [
      applicationGroupID
    ]
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  scope: workspace
  name: '${workspace.name}-WVDInsights'
  properties: {
    workspaceId: diagnosticWorkspaceID
    logs: [
      {
        category: null
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}
