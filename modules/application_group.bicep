@description('The name of the application group.')
param name string = 'AG-1'

@description('The location of the application group.')
param location string

param tags object

@description('The application group type. Either Desktop or RemoteApp.')
param applicationGroupType string = 'Desktop'

@description('The host pool id.')
param hostPoolID string

resource applicationGroup 'Microsoft.DesktopVirtualization/applicationGroups@2023-09-05' = {
  name: name
  location: location
  tags: tags
  properties: {
    applicationGroupType: applicationGroupType
    hostPoolArmPath: hostPoolID
  }
}

output id string = applicationGroup.id
