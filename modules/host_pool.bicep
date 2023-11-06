@description('The name of the host pool.')
param name string = 'HP-1'

@description('The location of the host pool.')
param location string

param tags object

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

var expirationTime = dateTimeAdd(baseTime, 'PT24H')

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' = {
  name: name
  location: location
  tags: tags
  properties: {
    hostPoolType: hostPoolType
    loadBalancerType: loadBalancingType
    preferredAppGroupType: preferredAppGroupType
    maxSessionLimit: maxSessionLimit
    registrationInfo: {
      expirationTime: expirationTime
      token: null
      registrationTokenOperation: 'Update'
    }
  }
}

output id string = hostPool.id
