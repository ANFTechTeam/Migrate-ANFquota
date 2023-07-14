param (
    [Parameter(Mandatory = $true)]
    [string]$action,
    [Parameter(Mandatory = $false)]
    [string]$resourceId,
    [Parameter(Mandatory = $false)]
    [string]$subnetResourceId,
    [Parameter(Mandatory = $false)]
    [string]$location,
    [Parameter(Mandatory = $false)]
    [string]$protocol
)

$timeStamp = get-date -Format yyyyMMddHHmmss
$logFileName = $timeStamp + 'quota.log'

Out-File -FilePath $logFileName -InputObject $timeStamp

# pre-requisites
# install-module az
# install-module az.netappfiles


# set variables
# $subscriptionId = ""
if($resourceId){
    $volumeResourceId = $resourceId
}else{
    $volumeResourceId = $null
}


$subscription = Get-AzContext

# Set-AzContext -subscriptionId $subscriptionId
function Clear-VolumeLegacyQuota($resourceIdToClear, $usageThreshold, $creationToken) {
    $volumeURI = $resourceIdToClear + '?api-version=2021-10-01'
    $volumeName = $resourceIdToClear.Split('/')[12]
    $resourceDetails = Get-AzResource -ResourceId $resourceIdToClear
    $usageThreshold.ToString()
    $payload = @'
{
        "name": "
'@

$payload += $volumeName + @'
",
        "type": "Microsoft.NetApp/netAppAccounts/capacityPools/volumes",
        "location": "
'@

$payload += $resourceDetails.Location + @'
",
        "properties": {
            "usageThreshold": "
'@

$payload += $usageThreshold.ToString() + @'
",
            "creationToken": "
'@

$payload += $creationToken + @'
",
            "isDefaultQuotaEnabled": false,
            "defaultUserQuotaInKiBs": 0,
            "defaultGroupQuotaInKiBs": 0
        }
}
'@

    $createParams = @{
        Path = $volumeURI
        Payload = $payload
        Method = 'PATCH'
    }
    $payload
    $createParams
    Write-Host -ForegroundColor Green "Disabling legacy default user and group quotas."
    Add-Content -Path $logFileName "Disabling legacy quota... "
    Out-File -FilePath $logFileName -Append -InputObject $resourceIdToClear
    Out-File -FilePath $logFileName -Append -InputObject $createParams
    Invoke-AzRestMethod @createParams
}


function New-VolumeWithLegacyQuota {
    $volumeURI = $resourceId + '?api-version=2021-10-01'
    $volumeName = $resourceId.Split('/')[12]
    $payload = @'
{
        "name": "
'@

$payload += $volumeName + @'
",
        "type": "Microsoft.NetApp/netAppAccounts/capacityPools/volumes",
        "location": "
'@        
$payload += $location + @'
",
        "properties": {
            "serviceLevel": "Standard",
            "usageThreshold": "107374182400",
'@
if($protocol -eq "cifs" -or $protocol -eq "smb"){
    $payload += 
@'
        
            "protocolTypes": [
                "CIFS"
            ],
'@
$payload += @'

    "creationToken": "
'@
$payload += $volumeName + @'
",
            "snapshotId": "",
            "subnetId": "
'@            
$payload += $subnetResourceId + @'        
",
            "isDefaultQuotaEnabled": true,
            "defaultUserQuotaInKiBs": 5120
        }
    }
'@
}else{
    $payload += @'

    "creationToken": "
'@
$payload += $volumeName + @'
",
            "snapshotId": "",
            "subnetId": "
'@            
$payload += $subnetResourceId + @'        
",
            "isDefaultQuotaEnabled": true,
            "defaultUserQuotaInKiBs": 5120,
            "defaultGroupQuotaInKiBs": 5120
        }
    }
'@
}

    $createParams = @{
        Path = $volumeURI
        Payload = $payload
        Method = 'PUT'
    }
    $createParams.Payload
    Invoke-AzRestMethod @createParams
}


function Get-VolumesWithOldQuota {
    $volumesWithOldQuota = @()
    $volumeList = Get-AzResource | where-object {$_.ResourceType -eq "Microsoft.NetApp/netAppAccounts/capacityPools/volumes"}
    Write-Host ''
    Write-Host '***********************************************************************'
    Write-Host 'Analyzing volumes in subscription:' $subscription.Subscription
    Write-Host '***********************************************************************'
    Write-Host ''
    Add-Content -Path $logFileName "The following volumes have the legacy quota..."
    foreach($volume in $volumeList){
        $volumeDetails = Get-AzNetAppFilesVolume -ResourceId $volume.ResourceId | Select-Object Name, ResourceGroupName, Location, Id, IsDefaultQuotaEnabled, DefaultUserQuotaInKiBs, DefaultGroupQuotaInKiBs
        Write-Host -NoNewLine -ForegroundColor DarkYellow $volume.name
        Write-host -NoNewLine ' has legacy quota enabled? '
        
        if($volumeDetails.IsDefaultQuotaEnabled -eq $true){
            $volumesWithOldQuota += $volumeDetails
            Add-Content -Path $logFileName -NoNewline "resourceId: "
            Out-File -FilePath $logFileName -Append -InputObject $volume.ResourceId
            Add-Content -Path $logFileName -NoNewline "isDefaultQuotaEnabled: "
            Out-File -FilePath $logFileName -Append -InputObject $volumeDetails.isDefaultQuotaEnabled
            Add-Content -Path $logFileName -NoNewline "defaultUserQuotaInKiBs: "
            Out-File -FilePath $logFileName -Append -InputObject $volumeDetails.defaultUserQuotaInKiBs
            Add-Content -Path $logFileName -NoNewline "defaultGroupQuotaInKiBs: "
            Out-File -FilePath $logFileName -Append -InputObject $volumeDetails.defaultGroupQuotaInKiBs
            Write-Host -ForegroundColor Green 'True'
        }else{
            Write-Host -ForegroundColor Red 'False'
        }
    }
    return $volumesWithOldQuota
}

function Start-MigrateLegacyQuota($resourceIdToMigrate){
    $fail = $false
    $volumeDetails = Get-AzNetAppFilesVolume -ResourceId $resourceIdToMigrate
    $volumeDetails
    if($null -ne $volumeDetails.DefaultUserQuotaInKiBs -and $volumeDetails.DefaultUserQuotaInKiBs -gt 0){
        Write-Host -ForegroundColor Green "Applying new default user quota with value:"$volumeDetails.DefaultUserQuotaInKiBs
        Add-Content -Path $logFileName "Applying new default user quota..."
        Out-File -FilePath $logFileName -Append -InputObject $resourceIdToMigrate
        Add-Content -Path $logFileName -NoNewLine "Default user quota value: "
        Out-File -FilePath $logFileName -Append -InputObject $volumeDetails.DefaultUserQuotaInKiBs
        if(Get-AzNetAppFilesVolumeQuotaRule -ResourceGroupName $resourceIdToMigrate.split('/')[4] -AccountName $resourceIdToMigrate.split('/')[8] -PoolName $resourceIdToMigrate.split('/')[10] -VolumeName $resourceIdToMigrate.split('/')[12] | Where-Object {$_.QuotaType -eq "DefaultUserQuota"}){
            Write-Host "New default user quota already exists."
        }else{
            try {
                New-AzNetAppFilesVolumeQuotaRule -ResourceGroupName $resourceIdToMigrate.split('/')[4] -AccountName $resourceIdToMigrate.split('/')[8] -PoolName $resourceIdToMigrate.split('/')[10] -VolumeName $resourceIdToMigrate.split('/')[12] -Location $volumeDetails.location -Name DefaultUserQuota -QuotaType DefaultUserQuota -QuotaSize $volumeDetails.DefaultUserQuotaInKiBs -ErrorAction Stop
            }
            catch {
                Write-Host "Unable to apply new default user quota."
                $fail = $true
                break
            }
        }
        
    }
    if($null -ne $volumeDetails.DefaultGroupQuotaInKiBs -and $volumeDetails.DefaultGroupQuotaInKiBs -gt 0) {
        Write-Host -ForegroundColor Green "Applying new default group quota with value:"$volumeDetails.DefaultGroupQuotaInKiBs
        Add-Content -Path $logFileName "Applying new default group quota..."
        Out-File -FilePath $logFileName -Append -InputObject $resourceIdToMigrate
        Add-Content -Path $logFileName -NoNewLine "Default group quota value: "
        Out-File -FilePath $logFileName -Append -InputObject $volumeDetails.DefaultGroupQuotaInKiBs
        if(Get-AzNetAppFilesVolumeQuotaRule -ResourceGroupName $resourceIdToMigrate.split('/')[4] -AccountName $resourceIdToMigrate.split('/')[8] -PoolName $resourceIdToMigrate.split('/')[10] -VolumeName $resourceIdToMigrate.split('/')[12] | Where-Object {$_.QuotaType -eq "DefaultGroupQuota"}){
            Write-Host "New default group quota already exists."
        }else{
            try {
                New-AzNetAppFilesVolumeQuotaRule -ResourceGroupName $resourceIdToMigrate.split('/')[4] -AccountName $resourceIdToMigrate.split('/')[8] -PoolName $resourceIdToMigrate.split('/')[10] -VolumeName $resourceIdToMigrate.split('/')[12] -Location $volumeDetails.location -Name DefaultGroupQuota -QuotaType DefaultGroupQuota -QuotaSize $volumeDetails.DefaultGroupQuotaInKiBs -ErrorAction stop
            }
            catch {
                Write-Host "Unable to apply new default group quota."
                $fail = $true
                break
            }
        }
        
    }
    if($fail -eq $false){
        Clear-VolumeLegacyQuota $resourceIdToMigrate $volumeDetails.UsageThreshold $volumeDetails.CreationToken
    }
    
}

if(!($action)){
    Write-Host ''
    Write-Host '**************************************************************************************************'
    write-host "No action specified, please use the '-action' flag with one of the following: 'list' or 'migrate'."
    Write-Host '**************************************************************************************************'
    Write-Host ''
}

if($action -eq "create"){
    New-VolumeWithLegacyQuota
}

if($action -eq "list"){
    $volumesWithOldQuota = Get-VolumesWithOldQuota
    Write-Host ''
    Write-Host '***********************************************'
    Write-Host 'These volumes are using the legacy quota system'
    Write-Host '***********************************************'
    $volumesWithOldQuota
}

if($action -eq "migrate"){
    if($null -eq $volumeResourceId){
        Write-Host ''
        Write-Host -NoNewLine 'No volume specified for migration. Would you like to see a list of volumes eligible for migration? '
        $listConfirm = Read-Host
        if($listConfirm -eq 'y' -or $listConfirm -eq 'Y'){
            $volumesWithOldQuota = Get-VolumesWithOldQuota
            $recordId = 0
            Write-Host ''
            Write-Host -NoNewLine -ForegroundColor Green "ID"
            Write-Host "`t Volume ResourceId"
            foreach($volume in $volumesWithOldQuota){
                Write-Host -NoNewLine -ForegroundColor Green $recordId
                Write-Host  "`t" $volume.Id
                $recordId ++
            }
            Write-Host ''
            Write-Host -NoNewLine "Which Volume "
            Write-Host -NoNewLine -ForegroundColor Green "'ID'" 
            Write-Host -NoNewLine ' from the list above would you like to migrate? '
            $volumeIndexToMigrate = Read-Host
            Write-Host ''
            Write-Host 'Volume ID' $volumeIndexToMigrate 'was selected for migration.'
            Write-Host ''
            $volumesWithOldQuota[$volumeIndexToMigrate].Id
            Start-MigrateLegacyQuota($volumesWithOldQuota[$volumeIndexToMigrate].Id)
        }
    }else{
        Start-MigrateLegacyQuota($volumeResourceId)
    }
    
}
