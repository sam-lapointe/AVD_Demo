@description('The suffix to add to the resource name.')
param suffix string

@description('The location of the backup vault.')
param location string

param tags object

@description('True to enable backup of the session hosts.')
param backupSessionHosts bool 

@description('True to enable bacup of the storage account.')
param backupStorageAccount bool 

@description('True to backup the Active Directory Domain Controller.')
param backupADDC bool 

@description('The number of days of the retention of Instant Restore Point.')
param instantRPRetention int 

@description('The number of days of the backup retention.')
param dailyRetention int 

param rgStorageName string = ''
param profileShareAccountName string = ''
param profileShareAccountID string = ''
param profileShareName string = ''

param rgDCName string = ''
param dcName string = ''
param dcID string = ''

param sessionHosts array

var backupFabric = 'Azure'
var dcProtectionContainer = 'iaasvmcontainer;iaasvmcontainerv2;${rgDCName};'
var dcProtectedItem = 'vm;iaasvmcontainerv2;${rgDCName};'
var shProtectionContainer = 'iaasvmcontainer;iaasvmcontainerv2;${resourceGroup().name};'
var shProtectedItem = 'vm;iaasvmcontainerv2;${resourceGroup().name};'


resource backupVault 'Microsoft.RecoveryServices/vaults@2023-06-01' = {
  name: 'BackupVault-${suffix}'
  location: location
  tags: tags
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

resource vmBackupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-04-01' = if (backupSessionHosts || backupADDC) {
  parent: backupVault
  name: 'Daily-Backup-VM'
  properties: {
    backupManagementType: 'AzureIaasVM'
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicyV2'
      scheduleRunFrequency: 'Daily'
      hourlySchedule: null
      dailySchedule: {
        scheduleRunTimes: [
          '2023-11-18T08:00:00.000Z'
        ]
      }
      weeklySchedule: null
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          '2023-11-18T08:00:00.000Z'
        ]
        retentionDuration: {
          count: dailyRetention
          durationType: 'Days'
        }
      }
      weeklySchedule: null
      monthlySchedule: null
      yearlySchedule: null
    }
    timeZone: 'Eastern Standard Time'
    policyType: 'V2'
    instantRpRetentionRangeInDays: instantRPRetention
  }
}

resource storageBackupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2023-04-01' = if (backupStorageAccount) {
  parent: backupVault
  name: 'Daily-Backup-Storage'
  properties: {
    backupManagementType: 'AzureStorage'
    workLoadType: 'AzureFileShare'
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: 'Daily'
      scheduleRunDays: null
      scheduleRunTimes: [
        '2023-11-18T08:00:00.000Z'
      ]
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          '2023-11-18T08:00:00.000Z'
        ]
        retentionDuration: {
          count: dailyRetention
          durationType: 'Days'
        }
      }
      weeklySchedule: null
      monthlySchedule: null
      yearlySchedule: null
    }
    timeZone: 'Eastern Standard Time'
  }
}

resource storageProtectionContainer 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers@2023-04-01' = if (backupStorageAccount) {
  name: '${backupVault.name}/${backupFabric}/storagecontainer;storage;${rgStorageName};${profileShareAccountName}'
  properties: {
    backupManagementType: 'AzureStorage'
    containerType: 'StorageContainer'
    sourceResourceId: profileShareAccountID
  }
}

resource assignBackupStorage 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2023-04-01' = if (backupStorageAccount) {
  parent: storageProtectionContainer
  name: 'AzureFileShare;${profileShareName}'
  properties: {
    protectedItemType: 'AzureFileShareProtectedItem'
    sourceResourceId: profileShareAccountID
    policyId: storageBackupPolicy.id
  }
}

resource assignBackupSH 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2023-04-01' = [for session in sessionHosts: if (backupSessionHosts) {
  name: '${backupVault.name}/${backupFabric}/${shProtectionContainer}${session.name}/${shProtectedItem}${session.name}'
  properties: {
    protectedItemType: 'Microsoft.ClassicCompute/virtualMachines'
    sourceResourceId: session.ID
    policyId: vmBackupPolicy.id
  }
}]

resource assignBackupDC 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2023-04-01' = if (backupADDC) {
  name: '${backupVault.name}/${backupFabric}/${dcProtectionContainer}${dcName}/${dcProtectedItem}${dcName}'
  properties: {
    protectedItemType: 'Microsoft.ClassicCompute/virtualMachines'
    sourceResourceId: dcID
    policyId: vmBackupPolicy.id
  }
}
