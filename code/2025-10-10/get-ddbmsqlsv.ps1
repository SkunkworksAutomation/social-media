[CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Database,
        [Parameter(Mandatory=$true)]
        [string]$FQDN
    )
# Import the modules
Import-Module .\skunkworks.dm.prototype.psm1 -Force

# Connect to the following servers
# Data Manager Servers
$dms = @(
    @{
        name = "dm-01.vcorp.local"
        lockbox = "C:\Program Files\DPSAPPS\common\lockbox"
        retention = 30
    }
)

# Interate over the data manager servers
foreach($dm in $dms){
    Write-Host "`n[$($dm.name)]: Connecting to the rest api"
    # Connect to the rest api
    connect-dmapi `
    -Server $dm.name `
    -Port 8443 `
    -Version 2
    
    Write-Host "`n[$($dm.name)]: Getting the asset information" `
    -ForegroundColor Cyan
    # Get asset information
    $filters = @(
        "name  eq `"$($Database)`"",
        "and details.database.clusterName eq `"$($FQDN)`"",
        "and protectionStatus eq `"PROTECTED`""
    )
    # Display the query in the console
    $endpoint = "assets"
    Write-Host "[GET]: /$($endpoint)`n[FILTER]: $($filters) `n[URI]: /$($endpoint)?filter=$($filters)"`
    -ForegroundColor Yellow
    
    $asset = get-dm `
    -Endpoint "$($endpoint)?filter=$($filters)" `
    -Version 2

    $asset |`
    select-object `
    id,`
    name,`
    type |`
    format-table -autosize

    # Terminating error of the database asset is not found on the defined host
    if(!$asset) {
        throw "[$($dm.name)]: $($Database) on $($FQDN) not found!"
    }

    Write-Host "`n[$($dm.name)]: Getting the protection policies" `
    -ForegroundColor Cyan

    # Display the query in the console
    $endpoint = "protection-policies"
    Write-Host "[GET]: /$($endpoint)`n[FILTER]: $($null) `n[URI]: /$($endpoint)/$($asset.protectionPolicy.id)"`
    -ForegroundColor Yellow
    
    $policy = get-dm `
    -Endpoint "$($endpoint)/$($asset.protectionPolicy.id)" `
    -Version 3

    # Display the protection policy
    $policy |`
    select-object `
    id,`
    name, `
    assetType | `
    format-table -autosize

    # Get the target object of the backup objective
    $target = ($policy.objectives | `
        where-object {
            $_.type -eq "BACKUP"
        }
    ).target
    
    # Get the storage system
    Write-Host "`n[$($dm.name)]: Getting the storage system and networking" `
    -ForegroundColor Cyan

    $endpoint = "storage-systems"
    Write-Host "[GET]: /$($endpoint)`n[FILTER]: $($null) `n[URI]: /$($endpoint)/$($target.storageContainerId)"`
    -ForegroundColor Yellow
    
    $dd = get-dm `
    -Endpoint "$($endpoint)/$($target.storageContainerId)" `
    -Version 2
    # Get the preferredInterface
    $interfaces = $dd.details.dataDomain.preferredInterfaces
    $interface = $interfaces | `
    where-object {
        $_.purposes -match "DATA" `
        -and $_.scope -eq "PUBLIC"
    }
    $interface | format-table -autosize

    # Get the storage unit
    $filters = @(
        "storageSystem.id  eq `"$($target.storageContainerId)`""
        "and id  eq `"$($target.storageTargetId)`""
    )
    Write-Host "`n[$($dm.name)]: Getting the storage unit" `
    -ForegroundColor Cyan

    $endpoint = "datadomain-mtrees"
    Write-Host "[GET]: /$($endpoint)`n[FILTER]: $($filters) `n[URI]: /$($endpoint)?filter=$($filters)"`
    -ForegroundColor Yellow
    $mtree = get-dm `
    -Endpoint "$($endpoint)?filter=$($filters)" `
    -Version 2

    $mtree |`
    select-object `
    id,`
    name,`
    @{l="credentialId";e={$_.credential.id}} |`
    format-table -autosize

    Write-Host "`n[$($dm.name)]: Getting the credentials" `
    -ForegroundColor Cyan
    $endpoint = "credentials"
    Write-Host "[GET]: /$($endpoint)`n[FILTER]: $($null) `n[URI]: /$($endpoint)/$($mtree.credential.id)"`
    -ForegroundColor Yellow
    $credential = get-dm `
    -Endpoint "$($endpoint)/$($mtree.credential.id)" `
    -Version 2

    $credential | select-object name | format-table -autosize
    Write-Host "`n[$($dm.name)]: Building the ddbmsqlsv backup command" `
    -ForegroundColor Cyan

    $cmd = @(
        "ddbmsqlsv.exe -c $($FQDN)",
        "-l full",
        "-y +$($dm.retention)",
        "-a `"NSR_DFA_SI_DD_HOST=$($interface.networkAddress)`"",
        "-a `"NSR_DFA_SI_DD_USER=$($credential.name)`"",
        "-a `"NSR_DFA_SI_DEVICE_PATH=/$($mtree.name)/PLCTLP-$($policy.id)`"",
        "-a `"NSR_DFA_SI_DD_LOCKBOX_PATH=$($dm.lockbox)`"",
        "-a `"NSR_SKIP_NON_BACKUPABLE_STATE_DB=TRUE`" MSSQL:$($asset.name)"
    )
    
    $cmd

    # Disconnect from the rest api
    disconnect-dmapi 
}