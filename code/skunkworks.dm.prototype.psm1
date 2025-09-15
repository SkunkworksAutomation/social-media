# DO NOT MODIFY BELOW THIS LINE
$global:dmAuthObject = $null
$global:dateFormat = "yyyy-MM-ddTHH:mm:ss.fffZ"
function connect-dmapi {
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$Server,
    [Parameter(Mandatory=$true)]
    [int]$Port,
    [Parameter(Mandatory=$true)]
    [int]$Version,
    [switch]$Refresh
)
begin {
        # CHECK TO SEE IF CREDENTIALS EXISTS IF NOT CREATE THEM
        $Exists = Test-Path -Path ".\$($Server).xml" -PathType Leaf
        if($Exists) {
            $Credential = Import-CliXml ".\$($Server).xml"
        } else {
            $Credential = Get-Credential
            $Credential | Export-CliXml ".\$($Server).xml"
        }  
    }
process {
    if(!$Refresh) {
        try {
            # Build the request body
            $body = @{
                username="$($Credential.username)"
                password="$(
                    ConvertFrom-SecureString `
                    -SecureString $Credential.password `
                    -AsPlainText
                )"
            }
            # Request a bearer token 
            $auth = `
            Invoke-RestMethod `
            -Uri "https://$($Server):$($Port)/api/v$($Version)/login" `
            -Method POST `
            -ContentType 'application/json' `
            -Body (ConvertTo-Json $body) `
            -SkipCertificateCheck

            # Create the response object
            $object = [ordered]@{
                dm = "https://$($Server):$($Port)/api"
                dmFqdn = $Server
                dmPort = $Port
                tokenApi = $auth.access_token
                tokenType = $auth.token_type
                tokenRefresh = $auth.refresh_token
                headerToken = @{
                    authorization = "$($auth.token_type) $($auth.access_token)"
                }
                headerRefresh = @{
                    authorization = "$($auth.token_type) $($auth.refresh_token)"
                }
            } # End Object
            $global:dmAuthObject = (
                New-Object -TypeName psobject -Property $object
            )
            # $global:dmAuthObject | format-table

        } catch {
            throw "[powerprotect]: Unable to connect to: $($Server)`n$($_.ErrorDetails)"
        }
    } else {
        try {
            # Build the request body
            $body = [ordered]@{
                grant_type = "refresh_token"
                refresh_token = $dmAuthObject.tokenRefresh
                scope = "aaa"
            }
            # Refresh the bearer token 
            $auth = `
                Invoke-RestMethod `
                -Uri "https://$($Server):$($Port)/api/v$($Version)/token" `
                -Method POST `
                -ContentType 'application/json' `
                -Headers ($dmAuthObject.headerRefresh) `
                -Body (ConvertTo-Json $body) `
                -SkipCertificateCheck

            # Update authentication properties
            $global:dmAuthObject.tokenApi = $auth.access_token
            $global:dmAuthObject.headerToken = @{
                authorization = "$($auth.token_type) $($auth.access_token)"
            }
            # $global:dmAuthObject | format-table
        }
        catch {
            throw "[powerprotect]: Unable to refresh token on: $($Server)`n$($_.ErrorDetails)"
        }
    } # End if / else
    } # End Process
} # End Function

function get-dm {
[CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [int]$Version,
        [Parameter(Mandatory=$true)]
        [string]$Endpoint
    )
    begin {
        $Page = 1
        $results = @()
        $retries = @(1..5)
        # Check to see if a filter was passed in
        $match = $Endpoint -match '\?(filter|filterType)='
        # Join path parameters to the end point
        $join = "&"
        if(!$match) {
            $join = "?"
        }
    }
    process {
        foreach($retry in $retries) {
            try {
                $query = Invoke-RestMethod `
                -Uri "$($dmAuthObject.dm)/v$($Version)/$($Endpoint)$($join)pageSize=100&page=$($Page)" `
                -Method GET `
                -ContentType 'application/json' `
                -Headers ($dmAuthObject.headerToken) `
                -SkipCertificateCheck
                
                $match = $query.psobject.Properties.name
                if($match -match "results") {
                    $results = $query.results
                } elseif($match -match "datastores") {
                    $results = $query.datastores
                } elseif($match -match "content") {
                    $results = $query.content
                } else {
                    $results = $query
                }
            }
            catch {
                if($query.code -eq 401){
                    # Refresh the bearer token
                    Write-Host "[$($dmAuthObject.dmFqdn)]: Refreshing bearer token..." -ForegroundColor Cyan
                    connect-dmapi `
                    -Server $dmAuthObject.dmFqdn `
                    -Port $dmAuthObject.dmPort `
                    -Version 2 `
                    -Refresh
                    Start-Sleep -Seconds 2
                } else {
                    [int]$Seconds = 15
                    Write-Host "[$($dmAuthObject.dmFqdn)]: ERROR: `n$($_) `nAttempt: $($retry) of $($retries.length)" -ForegroundColor Red
                    Write-Host "[$($dmAuthObject.dmFqdn)]: Attempting to recover in $($Seconds) seconds...`n" -ForegroundColor Yellow
                    Start-Sleep -Seconds $Seconds
                    if($retry -eq $retries.length) {
                        throw "[ERROR]: Could not recover from: `n$($_) in $($retries.length) attempts!"
                    }
                }
            } # End try / catch
        } # End foreach / retries
        
        foreach($retry in $retries) {
            try {
                if($query.page.totalPages -gt 1) {
                # Increment the page number
                $Page++
                # Page through the results
                do {
                    $Paging = Invoke-RestMethod `
                    -Uri "$($dmAuthObject.dm)/v$($Version)/$($Endpoint)$($join)pageSize=100&page=$($Page)" `
                    -Method GET `
                    -ContentType 'application/json' `
                    -Headers ($dmAuthObject.headerToken) `
                    -SkipCertificateCheck

                    # CAPTURE THE RESULTS
                    $match = $Paging.psobject.Properties.name
                    if($match -match "results") {
                        $results += $Paging.results
                    } elseif($match -match "datastores") {
                        $results += $Paging.datastores
                    } elseif($match -match "content") {
                        $results = $query.content
                    } else {
                        $results = $query
                    }
                        # Increment the page number
                        $Page++   
                    } 
                    until ($Paging.page.number -eq $Query.page.totalPages)
                }
            }
            catch {
                if($query.code -eq 401){
                    # Refresh the bearer token
                    Write-Host "[$($dmAuthObject.dmFqdn)]: Refreshing bearer token..." -ForegroundColor Cyan
                    connect-dmapi `
                    -Server $dmAuthObject.dmFqdn `
                    -Port $dmAuthObject.dmPort `
                    -Version 2 `
                    -Refresh
                    Start-Sleep -Seconds 2
                } else {
                    [int]$Seconds = 15
                    Write-Host "[$($dmAuthObject.dmFqdn)]: ERROR: `n$($_) `nAttempt: $($retry) of $($retries.length)" -ForegroundColor Red
                    Write-Host "[$($dmAuthObject.dmFqdn)]: Attempting to recover in $($Seconds) seconds...`n" -ForegroundColor Yellow
                    Start-Sleep -Seconds $Seconds
                    if($retry -eq $retries.length) {
                        throw "[ERROR]: Could not recover from: `n$($_) in $($retries.length) attempts!"
                    }
                }
            } # End try / catch
        } # End foreach / retries
        
        return $results  
    } # End process
} # End function

function set-dm {
[CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [Parameter(Mandatory=$true)]
        [ValidateSet('PUT','POST','PATCH')]
        [string]$Method,
        [Parameter(Mandatory=$true)]
        [int]$Version,
        [Parameter(Mandatory=$false)]
        [object]$Body,
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    begin {}
    process {
        $retries = @(1..5)
        foreach($retry in $retries) {
            try {
                Write-Host "[PowerProtect]: $($Message)" -ForegroundColor Yellow 
                if($null -eq $Body) {
                    $action = Invoke-RestMethod -Uri "$($dmAuthObject.dm)/v$($Version)/$($Endpoint)" `
                    -Method $Method `
                    -ContentType 'application/json' `
                    -Headers ($dmAuthObject.headerToken) `
                    -SkipCertificateCheck
                } else {
                    $action = Invoke-RestMethod -Uri "$($dmAuthObject.dm)/v$($Version)/$($Endpoint)" `
                    -Method $Method `
                    -ContentType 'application/json' `
                    -Body ($Body | ConvertTo-Json -Depth 20) `
                    -Headers ($dmAuthObject.headerToken) `
                    -SkipCertificateCheck
                }
                break;   
            } catch {
                if($query.code -eq 401){
                    # Refresh the bearer token
                    Write-Host "[$($dmAuthObject.dmFqdn)]: Refreshing bearer token..." -ForegroundColor Cyan
                    connect-dmapi `
                    -Server $dmAuthObject.dmFqdn `
                    -Port $dmAuthObject.dmPort `
                    -Version 2 `
                    -Refresh
                    Start-Sleep -Seconds 2
                } else {
                    [int]$Seconds = 60
                    Write-Host "[PowerProtect]: ERROR: $($Message)`n$($_) `nAttempt: $($retry) of $($retries.length)" -ForegroundColor Red
                    Write-Host "[PowerProtect]: Attempting to recover in $($Seconds) seconds...`n" -ForegroundColor Yellow
                    Start-Sleep -Seconds $Seconds
                    if($retry -eq $retries.length) {
                        throw "[ERROR]: Could not recover from: `n$($_) in $($retries.length) attempts!"
                    }
                }
            }
        }
        
        Write-Host "[PowerProtect]: SUCCESS: $($Message)" -ForegroundColor Green
        $match = $action.psobject.Properties.name
        if($match -match "results") {
            return $action.results
        } else {
            return $action
        }
    } # End process
} # End function

function disconnect-dmapi {
    [CmdletBinding()]
    param (
    )
    begin {}
    process {
        # Log off the rest api
        Invoke-RestMethod -Uri "$($dmAuthObject.dm)/v2/logout" `
        -Method POST `
        -ContentType 'application/json' `
        -Headers ($dmAuthObject.headerToken) `
        -SkipCertificateCheck

        $global:dmAuthObject = $null
    } # End process
} # End function

Export-ModuleMember -Function *