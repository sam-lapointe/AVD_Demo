targetScope = 'subscription'

@description('The suffix to add to the resources name.')
param suffix string = 'AVD'

@description('The name of the resource group for the AVD resources.')
param rgNameAVD string = 'RG-${suffix}'

@description('The name of the resource group for the Domain Services resources.')
param rgNameDS string = 'RG-DS'

@description('The location of the resources.')
param location string = deployment().location

@description('Tags for the resources')
param tags object = {
  Usage: 'AVD'
}

@description('The domain name.')
param domainName string = 'slapointe.com'

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

@description('The domain admin username.')
@secure()
param domainAdminUsername string

@description('The domain admin password. Must be at least 12 characters.')
@secure()
@minLength(12)
param domainAdminPassword string

@description('The Organizational Unit that you want to add the session hosts to.')
param ouPath string = 'OU=SessionHosts,DC=slapointe,DC=com'

@description('The location of resources such as templates and DSC modules that the script is dependent')
param _artifactsLocation string 

@description('Auto-generated token to access _artifactsLocation')
@secure()
param _artifactsLocationSasToken string 


var dcPrivateIpAdress = '10.0.0.4'


resource rgAVD 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: rgNameAVD
  location: location
}

resource rgDS 'Microsoft.Resources/resourceGroups@2023-07-01' = {
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

module domainController 'modules/domain_controller.bicep' = {
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

module sessionHosts 'modules/session_host.bicep' = {
  scope: rgAVD
  name: 'sessionHosts'
  params: {
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
    hostPool
  ]
}
