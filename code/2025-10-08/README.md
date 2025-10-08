# Start a serial backups on assets within a protection policy
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

# Workflow
The code will iterate over each PPDM instance defined within $dms and perform the following actions:
- Connect to the rest api
- Query for the protected assets matching the filter critera
- Filter the results based on the asset name with a regex query
- Start an ad hock backup of of an asset, monitor until complete and move on to the next asset... 
- Logoff of the REST API