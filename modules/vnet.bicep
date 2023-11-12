@description('The name of the virutal network.')
param vnetName string = 'Vnet-1'

@description('Address Prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Subnet 1 Prefix')
param subnet1Prefix string = '10.0.0.0/24'

@description('Subnet 1 Name.')
param subnet1Name string = 'Subnet-1'

@description('The location of the virtual network')
param location string

@description('The network security group ID.')
param networkSecurityGroupID string

param tags object

@description('The DNS address(es) of the DNS Server(s) used by the VNET')
param dnsServerAddress array = []

var dhcpOptions = {
  dnsServers: dnsServerAddress
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    dhcpOptions: (empty(dnsServerAddress) ? null : dhcpOptions)
    subnets: [
      {
        name: subnet1Name
        properties: {
          addressPrefix: subnet1Prefix
          networkSecurityGroup: {
            id: networkSecurityGroupID
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
          ]
        }
      }
    ]
  }
}

output id string = vnet.id
