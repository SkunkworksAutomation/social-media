# Getting the protection policies source DD systems, storage unit and replication target DD systems and storage units
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
- Query for the protect policies
- Build a count of the number of replication objectives in each policy
- Sort the results in descending order
- Query for all data somain mtrees (attached dd systems)
- Iterate over the policies query
    - Get the BACKUP and REPLICATION objective details from the policy
    - Build the report object
- Export the report to a csv file
- Logoff of the REST API