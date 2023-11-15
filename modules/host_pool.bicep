@description('The name of the host pool.')
param name string = 'HP-1'

@description('The location of the host pool.')
param location string

param tags object

@description('True if it is for an Azure Active Directory joined environment, else False.')
param isAADJoined bool

@description('The preferred app group type. Either Desktop or RemoteApp.')
@allowed([
  'Desktop'
  'RemoteApp'
])
param preferredAppGroupType string = 'Desktop'

@description('The type of the host pool. Either Personal or Pooled.')
@allowed([
  'Personal'
  'Pooled'
])
param hostPoolType string = 'Pooled'

@description('The type of load balancing algorithm. Either BreadthFirst or DepthFirst.')
@allowed([
  'BreadthFirst'
  'DepthFirst'
])
param loadBalancingType string = 'DepthFirst'

@description('The maximum amount of session per VM.')
param maxSessionLimit int

@description('The current time, used to create the registration token.')
param baseTime string = utcNow('u')

var expirationTime = dateTimeAdd(baseTime, 'PT2H')

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
  name: name
  location: location
  tags: tags
  properties: {
    hostPoolType: hostPoolType
    loadBalancerType: loadBalancingType
    preferredAppGroupType: preferredAppGroupType
    maxSessionLimit: maxSessionLimit
    customRdpProperty: 'drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;use multimon:i:1;${(isAADJoined ? 'targetisaadjoined:i:1' : '')}'
    registrationInfo: {
      expirationTime: expirationTime
      token: null
      registrationTokenOperation: 'Update'
    }
  }
}

output id string = hostPool.id
output token string = reference(hostPool.id).registrationInfo.token
