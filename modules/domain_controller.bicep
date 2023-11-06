@description('The suffix to add to the resources name.')
param suffix string = 'DC'

@description('The location of the Session Hosts.')
param location string

param tags object

@description('The VM Size.')
@allowed([
  'Standard_B2s'
  'Standard_B2ms'
])
param vmSize string = 'Standard_B2s'

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

@description('The private ip adress for the DC.')
param dcPrivateIpAdress string

@description('The location of resources such as templates and DSC modules that the script is dependent')
param _artifactsLocation string

@description('Auto-generated token to access _artifactsLocation')
@secure()
param _artifactsLocationSasToken string 


resource networkInterface 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'nic-${suffix}-1'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: dcPrivateIpAdress
          subnet: {
            id: '${vnetID}/subnets/${subnetName}'
          }
        }
      }
    ]
  }
}

resource vmDC 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: '${suffix}-1'
  location: location
  tags: tags
  properties: {
    osProfile: {
      computerName: '${suffix}-1'
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
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition-hotpatch'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
  }
}

resource vmDC_CreateADForest 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: vmDC
  name: 'CreateAdForest'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.24'
    autoUpgradeMinorVersion: true
    settings: {
      configuration: {
        url: _artifactsLocation
        script: 'CreateADPDC.ps1'
        function: 'CreateADPDC'
      }
      configurationArguments: {
        domainName: domainName
      }
    }
    protectedSettings: {
      configurationUrlSasToken: _artifactsLocationSasToken
      configurationArguments: {
        adminCreds: {
          userName: domainAdminUsername
          password: domainAdminPassword
        }
      }
    }
  }
}
