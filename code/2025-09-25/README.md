# Get asset capacity discovered, licensed and copy count
## Dependencies
- [PowerShell 7](https://github.com/powershell/powershell/releases)

## Pre-work:
- ### Update the $dms variable within the workflow script
    - name: The FQDN or IP address of the target PowerProtect Data Manager Server
```
$dms = @(
@{
        name = "192.xxx.xxx.xx1"
    },
@{
        name = "192.xxx.xxx.xx2"
    }
)
```

# Workflow
The code will iterate over each PPDM instance defined within $dms and perform the following actions:
- Connect to the rest api
- Query for the protected assets with a last available copy time
    - Query for the copy map to get a copy count
- Export the report to a csv file
- Logoff of the REST API