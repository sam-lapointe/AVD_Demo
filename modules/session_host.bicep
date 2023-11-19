@description('The suffix to add to the resources name.')
param suffix string 

@description('The location of the Session Hosts.')
param location string

param tags object

@description('True to enable diagnostics for the Azure Virtual Deskop resources.')
param enableDiagnostics bool

@description('True if it is for an Azure Active Directory joined environment, else False.')
param isAADJoined bool

@description('The VM Size.')
@allowed([
  'Standard_B2s'
  'Standard_B2ms'
])
param vmSize string = 'Standard_B2s'

@description('The number of session host to create.')
param sessionHostNum int

@description('The virtual network ID.')
param vnetID string

@description('The subnet name.')
param subnetName string

@description('The local admin username.')
@secure()
param localAdminUsername string

@description('The local admin password.')
@secure()
param localAdminPassword string

@description('The domain name that the VM will join.')
param domainName string

@description('The domain admin username.')
@secure()
param domainAdminUsername string

@description('The domain admin password.')
@secure()
param domainAdminPassword string

@description('Set of bit flags that define the join options. Default value of 3 is a combination of NETSETUP_JOIN_DOMAIN (0x00000001) & NETSETUP_ACCT_CREATE (0x00000002) i.e. will join the domain and create the account on the domain. For more information see https://msdn.microsoft.com/en-us/library/aa392154(v=vs.85).aspx')
param domainJoinOptions int = 3

param ouPath string

@description('The URL for the configuration module needed to join a VM as a session host.')
param avdAgentModuleURL string = 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02507.246.zip'

@description('The host pool token used to add the session hosts to the host pool.')
param hostPoolToken string

param diagnosticWorkspaceID string 

param dataCollectionRuleID string

// Retrieve the host pool info to pass into the module that builds session hosts. These values will be used when invoking the VM extension to install AVD agents.
resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2023-09-05' existing = {
  name: 'hp-${suffix}'
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2023-05-01' = [for i in range(0, sessionHostNum): {
  name: 'nic-${take(suffix, 9)}-${i + 1}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${vnetID}/subnets/${subnetName}'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}]

resource sessionHost 'Microsoft.Compute/virtualMachines@2023-07-01' = [for i in range(0,sessionHostNum): {
  name: 'vm-${take(suffix, 9)}-${i + 1}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    osProfile: {
      computerName: 'vm-${take(suffix, 9)}-${i + 1}'
      adminUsername: localAdminUsername
      adminPassword: localAdminPassword
      windowsConfiguration: {
        timeZone: 'Eastern Standard Time'
      }
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'microsoftwindowsdesktop'
        offer: 'office-365'
        sku: 'win11-21h2-avd-m365'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          properties: {
            primary: true
          }
          id: networkInterface[i].id
        }
      ]
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
    }
  }
  dependsOn: [networkInterface[i]]
}]

resource sessionHostDomainJoin 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = [for i in range(0, sessionHostNum): if(!isAADJoined){
  name: '${sessionHost[i].name}/JoinDomain'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      name: domainName
      ouPath: ouPath
      user: '${domainAdminUsername}@${domainName}'
      restart: true
      options: domainJoinOptions
    }
    protectedSettings: {
      password: domainAdminPassword
    }
  }
  dependsOn: [
    sessionHost[i]
  ]
}]

resource sessionHostAADLogin 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = [for i in range(0, sessionHostNum): if (isAADJoined) {
  name: '${sessionHost[i].name}/AADLoginForWindows'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '2.0'
    autoUpgradeMinorVersion: true
  }
  dependsOn: [
    sessionHost[i]
    sessionHostAVDAgent[i]
  ]
}]

resource sessionHostAVDAgent 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = [for i in range(0, sessionHostNum): {
  name: '${sessionHost[i].name}/AddSessionHost'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.73'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: avdAgentModuleURL
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostPool.name
        registrationInfoToken: hostPoolToken
        aadJoin: false
      }
    }
  }
  dependsOn: [
    sessionHostDomainJoin[i]
  ]
}]

resource sessionHostMonitor 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = [for i in range(0, sessionHostNum) : if(enableDiagnostics) {
  name: '${sessionHost[i].name}/AzureMonitorWindowsAgent'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
  dependsOn: [
    sessionHost[i]
  ]
}]

resource dcrAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = [for i in range(0, sessionHostNum) : if(enableDiagnostics) {
  name: '${sessionHost[i].name}-${suffix}-DCR'
  scope: sessionHost[i]
  properties: {
    dataCollectionRuleId: dataCollectionRuleID
  }
}]

output sessionHosts array = [for i in range(0,sessionHostNum): {
  name: sessionHost[i].name
  ID: sessionHost[i].id
}]
