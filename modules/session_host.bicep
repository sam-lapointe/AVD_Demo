@description('The suffix to add to the resources name.')
param suffix string 

@description('The location of the Session Hosts.')
param location string

param tags object

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
param avdAgentModuleURL string = 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.02482.227.zip'

@description('The host pool token used to add the session hosts to the host pool.')
param hostPoolToken string

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
  }
  dependsOn: [networkInterface[i]]
}]

resource sessionHostDomainJoin 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = [for i in range(0, sessionHostNum): {
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
