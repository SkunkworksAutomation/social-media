[CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [ValidateSet("SDM", "VADP", "INHERIT_FROM_POLICY")]
        [string]$DataMover
    )
# Import the modules
Import-Module .\skunkworks.dm.prototype.psm1 -Force

# Connect to the following servers
# Data Manager Servers
$dms = @(
    @{
        name = "dm-01.vcorp.local"
        prefix = "linux-"
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

    Write-Host "`n[$($dm.name)]: Getting the assets" `
    -ForegroundColor Cyan

    $filters = @(
        "protectionStatus eq `"PROTECTED`""
        "and lastDiscoveryStatus in (`"NEW`",`"DETECTED`",`"NOT_DETECTED`")",
        "and name lk `"$($dm.prefix)%25`""
    )
    $endpoint = "assets"
    Write-Host "[GET]: /$($endpoint)`n[FILTER]: $($filters) `n[URI]: /$($endpoint)?filter=$($filters)"`
    -ForegroundColor Cyan
    
    $assets = get-dm `
    -Endpoint "$($endpoint)?filter=$($filters)" `
    -Version 2
    
    # All assets matching the filter
    $all = $assets | select-object `
    name,`
    id,`
    type | `
    sort-object name
    
    Write-Host "`n[$($dm.name)]: All assets matching `n[FILTER]: $($filters)" `
    -ForegroundColor Yellow

    $all | `
    select-object `
    name,`
    type |`
    format-table -autosize

    # Kick off the updates for the backup mechanism
    $i=0
    foreach($vm in $all) {
        # Display the vm in progress
        Write-Host "`n[$($dm.name)]: Working on virtual machine : $($vm.name)" `
        -ForegroundColor Magenta

        # Build the request body
        $Body = [ordered]@{
            requests = @(
                @{
                    id = "$($i+1)"
                    body = [ordered]@{
                        id = $vm.id
                        details = @{
                            vm = @{
                                dataMoverType = "$($DataMover)"
                            }
                        }
                    }
                }
            )
        }

        # Update the backup mechanism
        $action1 = set-dm `
        -Endpoint "assets-batch" `
        -Method PATCH `
        -Version 2 `
        -Body $Body `
        -Message "Updating backup mechanism on $($vm.name)"
        $i++;

        # Throttle the API requests
        Start-Sleep -seconds 1
    } # End foeach

    # Disconnect from the rest api
    disconnect-dmapi     
}