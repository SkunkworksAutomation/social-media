# Start backups serially on assets within a protection policy
## Dependencies
- [PowerShell 7](https://github.com/powershell/powershell/releases)

## Pre-work:
- ### Update the $dms variable within the workflow script
    - name: The FQDN or IP address of the target PowerProtect Data Manager Server
    - policy: The name of the protection policy to pull the asset list from
```
$dms = @(
    @{
        name = "dm-01.vcorp.local"
        policy= "YourProtectionPolicyName"
    }
)
```

## Usage:
### PS C:\social-media> .\start-serialbackup.ps1 -role dbs
### Where "dbs" appears in characters 5,6,7 of the virtual machines dispaly name
### Note: This can be adjusted to align with any naming convention

# Workflow
The code will iterate over each PPDM instance defined within $dms and perform the following actions:
- Connect to the rest api
- Query for the protected assets matching the filter critera
- Filter the results based on the asset name matching a regular expression
    - Note: in this example the regex is looking characters 5,6,7 of the vm display name to determine its role to see if we are going to back it up or not
- Start an ad hock backup of the assets serially, waiting on each to complete before triggering the next 
- Logoff of the REST API