## Introduction

You can use this tool, Migrate-ANFquota.ps1, to migrate Azure NetApp Files volumes from the 'legacy default quota' system to the 'new default quota' system. 

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

### List all volumes which have the 'legacy default quota' enabled
```powershell
./Migrate-ANFquota.ps1 -action list
```

### Migrate a volume interactively
```powershell
./Migrate-ANFquota.ps1 -action migrate
```

### Migrate a specific volume by providing the volume resource Id
```powershell
./Migrate-ANFquota.ps1 -action migrate -resourceId <volume resource id>
```