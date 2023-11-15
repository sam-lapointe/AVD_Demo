targetScope = 'subscription'

@description('The suffix to add to the resources name.')
param suffix string = 'AVD1'

@description('The name of the resource group for the AVD resources.')
param rgNameAVD string = 'RG-${suffix}'

@description('The name of the resource group for the storage account of the AVD infrastructure.')
param rgNameAVDStorage string = 'RG-${suffix}-Storage'

@description('The name of the resource group for the Domain Services resources.')
param rgNameDS string = 'RG-DS'

@description('The location of the resources.')
param location string = deployment().location

@description('Tags for the resources')
param tags object = {
  Usage: 'AVD'
}

@description('True if it is for an Azure Active Directory joined environment, else False.')
param isAADJoined bool = true

@description('True if you use FSLogix for the profiles and need the storage created, else False.')
param fsLogix bool = false

@description('The domain name, if not AAD Joined')
param domainName string = ''

@description('The virtual network name.')
param vnetName string = 'Vnet-${suffix}'

@description('The virtual network subnet name.')
param subnetName string = 'Subnet-${suffix}'

@description('The number of session host to create.')
param sessionHostNum int = 1

@description('The host pool max session limit per VM.')
param maxSessionLimit int = 2

@description('The session host local admin username.')
@secure()
param localAdminUsername string

@description('The session host local admin password. Must be at least 12 characters.')
@secure()
@minLength(12)
param localAdminPassword string

@description('The domain admin username, if not AAD Joined')
@secure()
param domainAdminUsername string = ''

@description('The domain admin password, if not AAD Joined. Must be at least 12 characters.')
@secure()
param domainAdminPassword string = ''

@description('The Organizational Unit that you want to add the session hosts to.')
param ouPath string = 'OU=SessionHosts,DC=slapointe,DC=com'

@description('The location of resources such as templates and DSC modules that the script is dependent')
param _artifactsLocation string = ''

@description('Auto-generated token to access _artifactsLocation')
@secure()
param _artifactsLocationSasToken string = ''


var dcPrivateIpAdress = '10.0.0.4'


resource rgAVD 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgNameAVD
  location: location
}

resource rgAVDStorage 'Microsoft.Resources/resourceGroups@2023-07-01' = if(fsLogix) {
  name: rgNameAVDStorage
  location: location
}

resource rgDS 'Microsoft.Resources/resourceGroups@2023-07-01' = if(!isAADJoined) {
  name: rgNameDS
  location: location
}

module networkSecurityGroup 'modules/nsg.bicep' = {
  scope: rgAVD
  name: 'nsg'
  params: {
    name: 'nsg-${suffix}'
    location: location
    tags: tags
  }
}

module vnet 'modules/vnet.bicep' = {
  scope: rgAVD
  name: 'vnet'
  params: {
    vnetName: vnetName
    subnet1Name: subnetName
    location: location
    tags: tags
    networkSecurityGroupID: networkSecurityGroup.outputs.id
  }
}

module hostPool 'modules/host_pool.bicep' = {
  scope: rgAVD
  name: 'hostPool'
  params: {
    name: 'hp-${suffix}'
    location: location
    tags: tags
    isAADJoined: isAADJoined
    maxSessionLimit: maxSessionLimit
  }
}

module applicationGroup 'modules/application_group.bicep' = {
  scope: rgAVD
  name: 'applicationGroup'
  params: {
    name: 'ag-${suffix}'
    hostPoolID: hostPool.outputs.id
    location: location
    tags: tags
  }
}

module workspace 'modules/workspace.bicep' = {
  scope: rgAVD
  name: 'workspace'
  params: {
    name: 'ws-${suffix}'
    location: location
    tags: tags
    applicationGroupID: applicationGroup.outputs.id
  }
}

module storage 'modules/storage.bicep' = if(fsLogix) {
  scope: rgAVDStorage
  name: 'storage'
  params: {
    location: location
    subnetName: subnetName
    suffix: suffix
    tags: tags
    vnetID: vnet.outputs.id
  }
}

module keyvault 'modules/key_vault.bicep' = {
  scope: rgAVD
  name: 'keyVault'
  params: {
    location: location
    secretsObject: {
        secrets: [
          {
            secretName: 'localAdminUsername'
            secretValue: localAdminUsername
          }
          {
            secretName: 'localAdminPassword'
            secretValue: localAdminPassword
          }
          {
            secretName: 'domainAdminUsername'
            secretValue: domainAdminUsername
          }
          {
            secretName: 'domainAdminPassword'
            secretValue: domainAdminPassword
          }
        ]
      }
    suffix: suffix
    tags: tags
  }
}

module domainController 'modules/domain_controller.bicep' = if(!isAADJoined) {
  scope: rgDS
  name: 'domainController'
  params: {
    _artifactsLocation: _artifactsLocation
    _artifactsLocationSasToken: _artifactsLocationSasToken
    dcPrivateIpAdress: dcPrivateIpAdress
    domainAdminPassword: domainAdminPassword
    domainAdminUsername: domainAdminUsername
    domainName: domainName
    localAdminPassword: localAdminPassword
    localAdminUsername: localAdminUsername
    location: location
    subnetName: subnetName
    tags: tags
    vnetID: vnet.outputs.id
  }
}

module updateVnetDNS1 'modules/vnet.bicep' = if(!isAADJoined) {
  scope: rgAVD
  name: 'updateVnetDNS1'
  params: {
    vnetName: vnetName
    subnet1Name: subnetName
    location: location
    tags: tags
    networkSecurityGroupID: networkSecurityGroup.outputs.id
    dnsServerAddress: [
      dcPrivateIpAdress
    ]
  }
  dependsOn: [
    domainController
  ]
}

module sessionHosts 'modules/session_host.bicep' = {
  scope: rgAVD
  name: 'sessionHosts'
  params: {
    isAADJoined: isAADJoined
    hostPoolToken: hostPool.outputs.token
    domainAdminPassword: domainAdminPassword
    domainAdminUsername: domainAdminUsername
    domainName: domainName
    localAdminPassword: localAdminPassword
    localAdminUsername: localAdminUsername
    location: location
    ouPath: ouPath
    sessionHostNum: sessionHostNum 
    subnetName: subnetName
    suffix: suffix
    tags: tags
    vnetID: vnet.outputs.id
  }
  dependsOn: [
    domainController
    updateVnetDNS1
    hostPool
  ]
}
