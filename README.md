## Release Notes

- July 27, 2023: fixed order of operations to remove quotas before applying new
- July 14, 2023: added logic to ignore quota rule if equal to 0
- July 14, 2023: added ability to specify protocol when creating test volume (smb/cifs/nfs)

## Introduction

You can use this tool, Migrate-ANFquota.ps1, to migrate Azure NetApp Files default user and group quotas. 

## Prerequisites and Considerations

It is recommended to use this tool from Azure Cloud Shell as the required PowerShell modules and other dependencies are already present.

Each time this script is executed a new log file will be created in the format: YYYYMMDDHHMMSSquota.log

## Instructions

### Clone this Repo from Azure Cloud Shell
```powershell
git clone https://github.com/ANFTechTeam/Migrate-ANFquota.git 
```

## Install PowerShell module Az.NetAppFiles
```powershell
Install-Module Az.NetAppFiles
```

### Use 'Set-AzContext' to set the Azure subscription
```powershell
Set-AzContext -SubscriptionId <subscription ID>
```

### List all volumes which are eligible
```powershell
./Migrate-ANFquota.ps1 -action list
```

### Migrate a volume interactively
```powershell
./Migrate-ANFquota.ps1 -action migrate
```

### Migrate a specific volume by providing the volume resource Id
```powershell
./Migrate-ANFquota.ps1 -action migrate -resourceId <volume resource Id>
```

### Create a test volume to migrate

_Note: The **resource Id** specified in the following step is the resource Id of the volume you want to create._

For example, if you want to create a new volume with the name '**newVolume**' in capacity pool '**myCapacityPool**' within the NetApp account '**myAccount**' in resource group '**contoso.rg**', the resource Id would be as follows:

```
/subscriptions/12345678-90ab-cdef-ghij-123456789abc/resourceGroups/contoso.rg/providers/Microsoft.NetApp/netAppAccounts/myAccount/capacityPools/myCapacityPool/volumes/newVolume
```

```powershell
./Migrate-ANFquota.ps1 -action create -protocol smb|cifs|nfs -resourceId <volume resource Id> -location <region for new volume> -subnetResourceId <existing delegated subnet Resource Id>
```
