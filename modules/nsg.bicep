@description('The name of the network security group')
param name string = 'NSG-1'

@description('The location of the network security group')
param location string

param tags object

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

output id string = networkSecurityGroup.id
