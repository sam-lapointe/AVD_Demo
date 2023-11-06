@description('The name of the workspace.')
param name string = 'Workspace-General'

@description('The description of this workspace')
param wsDescription string = 'General Workspace.'

@description('Location of the workspace.')
param location string 

param tags object

@description('The application group to add to the workspace.')
param applicationGroupID string

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
