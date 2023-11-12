@description('The suffix to add to the resources name.')
param suffix string

@description('The location of the Key Vault.')
param location string

param tags object

@description('The Key Vault SKU. Either Standard or Premium.')
@allowed([
  'standard'
  'premium'
])
param sku string = 'standard'

@description('Specifies whether Azure Virtual Machines are permitted to retrieve certificates stored as secrets from the key vault.')
param enabledForDeployment bool = false

@description('Specifies whether Azure Disk Encryption is permitted to retrieve secrets from the vault and unwrap keys.')
param enabledForDiskEncryption bool = false

@description('Specifies whether Azure Resource Manager is permitted to retrieve secrets from the key vault.')
param enabledForTemplateDeployment bool = true

@description('Specifies all secrets {"secretName":"","secretValue":""} wrapped in a secure object.')
@secure()
param secretsObject object

@description('True to use RBAC and False to use AccessPolicies.')
param enableRbacAuthorization bool = true


resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-${suffix}-${take(uniqueString(resourceGroup().id), 4)}'
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: sku
    }
    tenantId: subscription().tenantId
    enabledForDeployment: enabledForDeployment
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enableRbacAuthorization: enableRbacAuthorization
  }
}

resource secrets 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = [for secret in secretsObject.secrets: {
  name: secret.secretName
  parent: kv
  properties: {
    attributes: {
      enabled: true
    }
    contentType: 'string'
    value: secret.secretValue
  }
}]
