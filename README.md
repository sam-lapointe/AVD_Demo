# Azure Virtual Desktop Demo

This repository is designed to simplify the creation of Azure Virtual Environments, whether you require the Virtual Desktop to be Azure Active Directory (AAD) joined or Active Directory (AD) joined.

## Disclaimer

This project is unfinished and will not be updated. As a result, the repository may not be well-organized or fully functional. However, it still may provide value to some users.

## Default Deployment Resources

![Default AVD Environment](https://github.com/sam-lapointe/AVD_Demo/blob/main/AVD-Diagram.png)

## How to deploy

1. Clone this repository.

2. Deploy with Azure CLI or Azure Powershell
    - With Azure Powershell:
        ```
        \\ Connect to your account
        Connect-AzAccount
        \\ Select your subscription
        Set-AzContext -Subscription "xxxx-xxxx-xxxx-xxxx" 
        \\ Deploy the template
        New-AzSubscriptionDeployment -Location <location> -TemplateFile <path-to-bicep>
        ```
    - With Azure CLI:
        ```
        \\ Connect to your account
        az login
        \\ Select your subscription
        az account set --subscription <Name or ID of subscription>
        \\ Deploy the template
        az deployment sub create --location <location> --template-file <path-to-bicep>
        ```
        ### You can ignore the warnings.

3. Assign the users to the application group.
4. Assign the users the Virtual Machine User Login role on the Session Host.

## Resources

* https://github.com/pauldotyu/azure-virtual-desktop-bicep
* https://github.com/jamesatighe/AVD-BICEP
* https://www.cloudninja.nu/post/2021/02/using-azure-dsc-to-configure-a-new-active-directory-domain/
* https://blog.azinsider.net/azure-bicep-deploy-a-pair-of-azure-vms-running-highly-available-active-directory-domain-c91cc9c5950d
* https://lrottach.hashnode.dev/avd-working-with-registration-tokens