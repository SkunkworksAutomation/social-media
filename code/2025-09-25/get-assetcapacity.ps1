# Import the modules
Import-Module .\skunkworks.dm.prototype.psm1 -Force

# Connect to the following servers
# Data Manager Servers
$dms = @(
    @{
        name = "dm-01.vcorp.local"
    }
)
# Define a report variable
$report = @()
# Interate over the data manager servers
foreach($dm in $dms){
    Write-Host "`n[$($dm.name)]: Connecting to the rest api"
    # Connect to the rest api
    connect-dmapi `
    -Server $dm.name `
    -Port 8443 `
    -Version 2

    Write-Host "`n[$($dm.name)]: Getting the assets" `
    -ForegroundColor Cyan
    # lastDiscoveryStatus in ("NEW","DETECTED","NOT_DETECTED")
    $filters = @(
        "protectionStatus eq `"PROTECTED`""
        "and lastAvailableCopyTime ne null",
        "and lastDiscoveryStatus in (`"NEW`",`"DETECTED`",`"NOT_DETECTED`")",
        "and type ne `"DR`""
    )
    $endpoint = "assets"
    Write-Host "[GET]: /$($endpoint)`n[FILTER]: $($filters) `n[URI]: /$($endpoint)?filter=$($filters)"`
    -ForegroundColor Cyan
    
    $assets = get-dm `
    -Endpoint "$($endpoint)?filter=$($filters)" `
    -Version 2
    $i=0
    foreach($asset in $assets){
        $endpoint = "assets/$($asset.id)/copy-map"
        Write-Host "`n[$($i+1) of $($assets.length)]`n[GET]: /$($endpoint)`n[FILTER]: $($filters) `n[URI]: /$($endpoint)?filter=$($filters)"`
        -ForegroundColor Yellow
        
        $map = get-dm `
        -Endpoint "$($endpoint)" `
        -Version 2

        $assetHost = $null
        switch($asset.type) {
            'FILE_SYSTEM' {
                $assetHost = $asset.details.fileSystem.clusterName
                break;
            }
            'KUBERNETES' {
                $assetHost = $asset.details.k8s.inventorySourceName
                break;
            }
            'NAS_SHARE' {
                $assetHost = $asset.details.nasShare.nasServer.name
                break;
            }
            'VMAX_STORAGE_GROUP' {
                $assetHost = $asset.details.vmaxStorageGroup.coordinatingHostname
                break;
            }
            'VMWARE_VIRTUAL_MACHINE'{
                $assetHost = $asset.details.vm.hostName
                break;
            }
            default {
                $assetHost = $asset.details.database.clusterName
                break;
            }
        }
        $Date = Get-Date($asset.lastAvailableCopyTime)
        $object = [ordered]@{
            id = $asset.id
            assetName = $asset.name
            assetHost = $assetHost
            assetType  = $asset.type
            assetSizeBytes = $asset.size
            assetProtectSizeBytes = $asset.protectionCapacity.size
            totalCopyCount = $map.totalCopyCount
            totalSizeBytes = $map.totalSizeBytes
            policyName = $asset.protectionPolicy.name
            lastAvailableCopyTime = $Date.ToLocalTime()
        }

        # Build the report
        $report += (New-Object -TypeName psobject -Property $object)
        # Throttle the rest api calls
        Start-Sleep -Seconds 1
        # Increment the iterator
        $i++
    }
    
    $report | Export-Csv .\asset-capacity.csv
    # Disconnect from the rest api
    disconnect-dmapi     
}