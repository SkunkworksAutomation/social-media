[CmdletBinding()]
    param (
        [Parameter( Mandatory=$true)]
        [string]$role
    )
# Import the modules
Import-Module .\skunkworks.dm.prototype.psm1 -Force

# Connect to the following servers
# Data Manager Servers
$dms = @(
    @{
        name = "dm-01.vcorp.local"
        policy = "policy-moneris"
        characters = @(5,6,7)
        retention = 28
    }
)

# Define the regex pattern
$regex = "^$($role)$"

# Interate over the data manager servers
foreach($dm in $dms){

    [array]$chars = $dm.characters

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
        "and protectionPolicy.name eq `"$($dm.policy)`""
    )
    $endpoint = "assets"
    Write-Host "[GET]: /$($endpoint)`n[FILTER]: $($filters) `n[URI]: /$($endpoint)?filter=$($filters)"`
    -ForegroundColor Cyan
    
    $assets = get-dm `
    -Endpoint "$($endpoint)?filter=$($filters)" `
    -Version 2
    
    # All assets matching role
    $all = $assets | select-object `
    name,`
    id,`
    type,`
    @{l="policyId";e={$_.protectionPolicy.id}},`
    @{l="policyName";e={$_.protectionPolicy.name}},`
    @{l="role";e={
        ($_.name).Substring($chars[0]-1,$chars.length)
    }} | `
    sort-object name
    
    Write-Host "`n[$($dm.name)]: All assets matching role `"$($role)`"" `
    -ForegroundColor Yellow

    $all | `
    select-object `
    name,`
    type,`
    role |`
    format-table -autosize

    # Filtered assets matching our regex pattern
    $filtered = $all | where-object {$_.role -match $regex}
    Write-Host "`n[$($dm.name)]: Filtered assets role matching pattern `"$($regex)`"" `
    -ForegroundColor Green

    $filtered | `
    select-object `
    name,`
    type,`
    role |`
    format-table -autosize
    
    # Check to see if there is a backup running for any of the filtered assets
    $filters = @(
        "category eq `"BACKUP`""
        "and classType eq `"JOB`"",
        "and references.name in (`"$($filtered.name -join '","')`")",
        "and state in (`"RUNNING`",`"QUEUED`")"
    )
    $endpoint = "activities"
    Write-Host "[GET]: /$($endpoint)`n[FILTER]: $($filters) `n[URI]: /$($endpoint)?filter=$($filters)"`
    -ForegroundColor Cyan
    
    $running = get-dm `
    -Endpoint "$($endpoint)?filter=$($filters)" `
    -Version 3
  
    if($running.length -lt 1){
        
        # Kick off serial backups and monitoring
        foreach($vm in $filtered) {
            # Display the vm in progress
            Write-Host "`n[$($dm.name)]: Working on virtual machine : $($vm.name)" `
            -ForegroundColor Magenta

            # Get the protection policy details
            Write-Host "`n[$($dm.name)]: Getting protection policy details : $($vm.policyName)" `
            -ForegroundColor Cyan
            
            # Filters
            $filters  = @(
                "id eq `"$($vm.policyId)`""
            )
            $endpoint = "protection-policies"

            Write-Host "`n[GET]: /$($endpoint)`n[FILTER]: $($filters ) `n[URI]: /$($endpoint)?filter=$($filters)`n"`
            -ForegroundColor Yellow

            $policy = get-dm `
            -Endpoint "$($endpoint)?filter=$($filters)" `
            -Version 3

            $policy | `
            Select-Object `
            id, `
            name, `
            assetType | `
            format-table -autosize

            # Build the request body
            [string]$objectiveId = (
                $policy.objectives | `
                Where-Object {$_.type -eq "BACKUP"}
            ).id
            $Body = [ordered]@{
                source = [ordered]@{
                    assetIds = @(
                        $vm.id
                    )
                    protectionGroupIds = @()
                }
                policy = [ordered]@{
                    id = $policy.id
                    objectives = @(
                        [ordered]@{
                            id = $objectiveId
                            operation = @{
                                backupLevel = "SYNTHETIC_FULL"
                            }
                            retentions = @(
                                [ordered]@{
                                    time = @(
                                        [ordered]@{
                                            type = "RETENTION"
                                            unitValue = $dm.retention
                                            unitType = "DAY"
                                        }
                                        
                                    )
                                }
                            )
                        }
                    )
                }
            } # End body

            
            # Start the ad hock backup
            $action1 = set-dm `
            -Endpoint "protections" `
            -Method POST `
            -Version 3 `
            -Body $Body `
            -Message "Starting ad hoc backup for $($vm.name)"
            
            $action1 | select-object `
            status,`
            objectiveId,`
            activityId |`
            format-table -autosize

            $backup = $action1 | `
            where-object {
                $_.objectiveId -match "^$($objectiveId)$"
            }

            # Monitor until complete
            Write-Host "`n[$($dm.name)]: Monitoring backup activity id: $($backup.activityId)" -ForegroundColor Cyan
            do {
                $filters  = @(
                    "id eq `"$($backup.activityId)`""
                )
                $endpoint = "activities"
                $monitor = get-dm `
                -Endpoint "$($endpoint)?filter=$($filters)" `
                -Version 3

                Write-Progress `
                -Activity "Monitoring activity id: $($backup.activityId)" `
                -Status "Percent complete: $($monitor.progress)%" `
                -PercentComplete $($monitor.progress)
                
                # Poll every x seconds
                Start-Sleep -Seconds 20
            }
            until($monitor.state -eq "COMPLETED")

            Start-Sleep -seconds 1
        } # End foreach
        
    } else {
        Write-Host "[ABORTING]: Found the follwing asset jobs running" `
        -ForegroundColor Magenta
        
        $running | `
        select-object createdAt,displayId,
        @{l="assetName";e={($_.references|where-object{$_.usage -eq "ASSET"}).name }},`
        state | `
        format-table -autosize
    }
    
    # Disconnect from the rest api
    disconnect-dmapi     
}