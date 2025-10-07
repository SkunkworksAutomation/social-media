# Import the modules
Import-Module .\skunkworks.dm.prototype.psm1 -Force

# Connect to the following servers
# Data Manager Servers
$dms = @(
    @{
        name = "dm-01.vcorp.local"
    }
)

$report = @()
# Interate over the data manager servers
foreach($dm in $dms){
    Write-Host "`n[$($dm.name)]: Connecting to the rest api"
    # Connect to the rest api
    connect-dmapi `
    -Server $dm.name `
    -Port 8443 `
    -Version 2

    Write-Host "`n[$($dm.name)]: Getting the protection policies" `
    -ForegroundColor Cyan
    # Get all of the protection policies
    $filters = @(
        "purpose ne `"EXCLUSION`""
    )
    $endpoint = "protection-policies"
    Write-Host "[GET]: /$($endpoint)`n[FILTER]: $($filters) `n[URI]: /$($endpoint)?filter=$($filters)"`
    -ForegroundColor Yellow
    $policies = get-dm `
    -Endpoint "$($endpoint)?filter=$($filters)" `
    -Version 3
    # Get the policies with a replication objective
    $replobj = $policies | where-object {$_.objectives.type -eq "REPLICATION"}
    
    $counts = $replobj | `
    select-object `
    name,`
    @{l="replcount";e={($_.objectives | where-object {$_.type -eq "REPLICATION"}).length}} | `
    sort-object replcount -Descending

   # Load all of the mtree details
   Write-Host "`n[$($dm.name)]: Getting the dd and storage unit details" `
    -ForegroundColor Cyan
    $endpoint = "datadomain-mtrees"
    Write-Host "[GET]: /$($endpoint)`n[FILTER]: $($null) `n[URI]: /$($endpoint)"`
    -ForegroundColor Yellow
    $Mtrees = get-dm `
    -Endpoint "$($endpoint)" `
    -Version 2

    $i=0
    foreach($policy in $policies){
        $precent = [math]::Round((($i+1)/$policies.length)*100)
        Write-Progress `
        -Activity "Building the replication target report" `
        -Status "Percent complete: $($precent)%" `
        -PercentComplete $precent

        # Get the backup objective
        $source = $policy.objectives | `
        where-object {$_.type -eq "BACKUP"}

        # Get the replication objectives
        $targets = $policy.objectives | `
        where-object {$_.type -eq "REPLICATION"}
        
        # Create the base object
        $object = [ordered]@{
            policyName = $policy.name
            policyType = $policy.assetType
            policyDisabled = $policy.disabled
            
            # Add the source dd system name
            sDD = ($Mtrees | where-object {
                $_.id -eq $source.target.storageTargetId `
                -and $_.storageSystem.id `
                -eq $source.target.storageContainerId
            }
            )._embedded.storageSystem.name

            # Add the source su name
            sSU = ($Mtrees | where-object {
                $_.id -eq $source.target.storageTargetId `
                -and $_.storageSystem.id `
                -eq $source.target.storageContainerId
            }
            ).name
        }

        # Add in the mx number of replication destinations
        [int]$max = ($counts | select-object -first 1).replcount

        if( $targets.length -gt 0 ){
            foreach($item in @(1..$max)) {            
                # Add the replication dd system name
                $object."rDD$($item)" = (
                    $Mtrees | where-object {
                    $_.id -eq $targets[$item -1].target.storageTargetId `
                    -and $_.storageSystem.id `
                    -eq $targets[$item -1].target.storageContainerId
                })._embedded.storageSystem.name

                # Add the replication su name
                $object."rSU$($item)" = (
                $Mtrees | where-object {
                $_.id -eq $targets[$item -1].target.storageTargetId `
                -and $_.storageSystem.id `
                -eq $targets[$item -1].target.storageContainerId
                }).name
            }
        } else {
            # Add in the blank properties
            foreach($item in @(1..$max)) {
                $object."rDD$($item)" = $null
                $object."rSU$($item)" = $null
            }
        }
        $report += (new-object -TypeName psobject -Property $object)
        $i++
    } # End foreach
    # Output to csv
    $report | export-csv .\replicationtargets.csv

    # Disconnect from the rest api
    disconnect-dmapi     
}