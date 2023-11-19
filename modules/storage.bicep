@description('The suffix of the storage account.')
param suffix string 

@description('The location of the storage account.')
param location string

param tags object

@description('The virtual network ID.')
param vnetID string

@description('The subnet name.')
param subnetName string

@description('The profile share retention policy for deleted items.')
param retentionPolicyDays int = 7

@description('The profile share quota in GB. Minimum is 100GB. You pay for the quota, not the amount used.')
@minValue(100)
param profileShareQuota int = 100


resource profileShareAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'profilestorage${toLower(suffix)}${take(uniqueString(resourceGroup().id), 4)}'
  location: location
  tags: tags 
  sku: {
    name: 'Premium_LRS'
  }
  kind: 'FileStorage'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: false
    publicNetworkAccess: 'Enabled'
    allowCrossTenantReplication: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: [
        {
          id: '${vnetID}/subnets/${subnetName}'
        }
      ]
    }
    dnsEndpointType: 'Standard'
    largeFileSharesState: 'Enabled'
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
        table: {
          enabled: true
        }
        queue: {
          enabled: true
        }
      }
      requireInfrastructureEncryption: false
    }
  }
}

resource profileShareRetention 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: profileShareAccount
  name: 'default'
  properties: {
    protocolSettings: null
    shareDeleteRetentionPolicy: {
      enabled: true
      days: retentionPolicyDays
    }
  }
}

resource profileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: profileShareRetention
  name: 'profileshare-${toLower(suffix)}-${take(uniqueString(resourceGroup().id), 4)}'
  properties: {
    enabledProtocols: 'SMB'
    shareQuota: profileShareQuota
  }
}

output storageShareAccountName string = profileShareAccount.name
output storageShareAccountID string = profileShareAccount.id
output profileShareName string = profileShare.name
