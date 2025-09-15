# Import the modules
Import-Module .\skunkworks.dm.prototype.psm1 -Force

# Connect to the following servers
# Data Manager Servers
$dms = @(
    @{
        name = "ppdm-02.vcorp.local"
        policy = "vm-templates"
        folder = "Templates"
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

    # Qeury for the attached vcenters 
    $Filters = @(
        "type eq `"VMWARE_VCENTER`"",
        "and extendedData.internal ne true",
        "and extendedData.assetSource eq true"
    )
    
    $Endpoint = "infrastructure-objects"
    Write-Host "`n[GET]: /$($Endpoint)`n[FILTER]: $($Filters) `n[URI]: /$($Endpoint)?filter=$($Filters)"`
    -ForegroundColor Yellow
    $vcs = get-dm `
    -Endpoint "$($Endpoint)?filter=$($Filters)" `
    -Version 3
    
    if($vcs.length -gt 0) {

       # Display the results
        $vcs | `
        Select-Object `
        name, `
        type, `
        vendor, `
        version | `
        Format-Table -AutoSize

        foreach($vc in $vcs) {
        # Check for the credentials file
        $exists = Test-Path `
        -Path ".\$($vc.name).xml" `
        -PathType Leaf
        if($exists) {
            # Import the vcenter credential file
            $vcCred = Import-Clixml ".\$($vc.name).xml"

            } else {
                # Create the vcenter credential file
                $vcCred = Get-Credential
                $vcCred | Export-CliXml ".\$($vc.name).xml"
            }

            # Connect to the vcenter
            $connect = Connect-VIServer `
            -Server $vc.name `
            -Credential $vcCred
            
            # Check the connection
            if($connect.IsConnected -eq $true) {
                # Query for the templates
                $templates = Get-Template

                # Convert templates to vms
                Write-Host "[$($vc.name)]: Converting templates to virtual machines" `
                -ForegroundColor Cyan

                foreach($template in $templates) {
                    Set-Template -Template $template.name -ToVM -Confirm:$false
                }
               
                # Query until the query1 count matches the templates count
                do {
                    $Filters = @(
                        "details.vm.folder eq `"$($dm.folder)`"",
                        "and protectable eq true"
                    )
                    $Endpoint = "assets"
                    
                    Write-Host "[GET]: /$($Endpoint)`n[FILTER]: $($Filters) `n[URI]: /$($Endpoint)?filter=$($Filters)"`
                    -ForegroundColor Yellow

                    $query1 = get-dm `
                    -Endpoint "$($Endpoint)?filter=$($Filters)" `
                    -Version 2

                    if($query1.length -eq $templates.length){
                        Write-Host "[$($dm.name)]: Protectable assets: $($query1.length) = Templates: $($templates.length)" `
                        -ForegroundColor Green
                    } else {
                        Write-Host "[$($dm.name)]: Protectable assets: $($query1.length) != Templates: $($templates.length)" `
                        -ForegroundColor Magenta
                    }
                    Start-Sleep -Seconds 10
                }
                until($query1.length -eq $templates.length)
                
                Write-Host "`n[$($dm.name)]: Getting protection policy details : $($dm.policy)" -ForegroundColor Cyan
                # Get the protection policy
                $Filters = @(
                    "name eq `"$($dm.policy)`""
                )
                $Endpoint = "protection-policies"

                Write-Host "`n[GET]: /$($Endpoint)`n[FILTER]: $($Filters) `n[URI]: /$($Endpoint)?filter=$($Filters)`n"`
                -ForegroundColor Yellow

                $query2 = get-dm `
                -Endpoint "$($Endpoint)?filter=$($Filters)" `
                -Version 3

                # Display the target protection policy
                $query2 | Select-Object `
                id, `
                name, `
                assetType | `
                Format-List
                
                # Start the backup
                $Body = [ordered]@{
                    source = [ordered]@{
                        assetIds = $null
                        protectionGroupIds = @()
                    }
                    policy = [ordered]@{
                        id = $query2.id
                        objectives = @(
                            [ordered]@{
                                id = ($query2.objectives | Where-Object {$_.type -eq "BACKUP"}).id
                                operation = @{
                                    backupLevel = "SYNTHETIC_FULL"
                                }
                                retentions = @(
                                    [ordered]@{
                                        time = @(
                                            [ordered]@{
                                                type = "RETENTION"
                                                unitValue = 28
                                                unitType = "DAY"
                                            }
                                            
                                        )
                                    }
                                )
                            }
                        )
                    }
                } # End Body

                $action1 = set-dm `
                -Endpoint "protections" `
                -Method POST `
                -Version 3 `
                -Body $Body `
                -Message "Starting ad hoc backup for $($query2.name)"
                $action1 | format-list

                # Monitor until complete
                Write-Host "`n[$($dm.name)]: Monitoring backup activity id: $($action1.activityId)" -ForegroundColor Cyan
                do {
                    $Filters = @(
                        "id eq `"$($action1.activityId)`""
                    )
                    $Endpoint = "activities"
                    Write-Host "`n[GET]: /$($Endpoint)`n[FILTER]: $($Filters) `n[URI]: /$($Endpoint)?filter=$($Filters)"`
                    -ForegroundColor Yellow

                    $monitor = get-dm `
                    -Endpoint "$($Endpoint)?filter=$($Filters)" `
                    -Version 3

                    Write-Progress `
                    -Activity "Monitoring activity id: $($action1.activityId)" `
                    -Status "Percent complete: $($monitor.progress)%" `
                    -PercentComplete $($monitor.progress)
                  
                    # Poll every x seconds
                    Start-Sleep -Seconds 25
                }
                until($monitor.state -eq "COMPLETED")

                # Clear the progress bar
                Write-Progress `
                -Activity "Monitoring activity id: $($action1.activityId)" `
                -Completed

                # Convert the vms back to templates
                Write-Host "`n[$($vc.name)]: Converting virtual machines to templates" -ForegroundColor Cyan
                foreach($template in $templates) {
                    Set-VM -VM $template.name -ToTemplate -Confirm:$false
                }

            } else {
                throw "[ERROR]: Connecting to $($vc.name)..."
            }
            Disconnect-VIServer -Server $vc.name -Force -Confirm:$false
        }
    } # END IF
    
    # Disconnect from the rest api
    disconnect-dmapi     
}