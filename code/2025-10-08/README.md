# Start backups serially on assets within a protection policy
## Dependencies
- [PowerShell 7](https://github.com/powershell/powershell/releases)

## Pre-work:
- ### Update the $dms variable within the workflow script
    - name: The FQDN or IP address of the target PowerProtect Data Manager Server
    - prefix: This is for a like search. The prefix below will match all protected assets starting with linux-
        - Note: This can be adjusted, or removed to match your specific usecase
```
$dms = @(
    @{
        name = "dm-01.vcorp.local"
    }
)
```
- ### Update the $userTags variable within the workflow script
    - $userTags: VMWare virtual machine tag assigned to the asset
    - Note: The tagging and subsequent regex filter allows for more granular control over asset inclusion / exclusion in the workflow
```
$userTags = "PPDMBackupPolicy||T1_APP_PROD_TSDM"
```

# Workflow
The code will iterate over each PPDM instance defined within $dms and perform the following actions:
- Connect to the rest api
- Query for the protected assets matching the filter critera
- Filter the results based on the asset name matching a regular expression
    - Note: in this example the regex is looking characters 5,6,7 of the vm display name to determine its role to see if we are going to back it up or not
- Start an ad hock backup of the assets serially, waiting on each to complete before triggering the next 
- Logoff of the REST API