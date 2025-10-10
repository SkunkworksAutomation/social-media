# Build the cli backup command for ddbmsqlsv.exe
```
EXAMPLE:
================================================================================
ddbmsqlsv.exe -c sql-01.vcorp.local -l full -y +30d -a "NSR_DFA_SI_DD_HOST=192.168.1.235" -a "NSR_DFA_SI_DD_USER=policy-ss-mssql-dm-01-d244f" -a "NSR_DFA_SI_DEVICE_PATH=/policy-ss-mssql-dm-01-d244f/PLCTLP-828b29ca-5bd6-4b05-804f-ae79015a170c" -a "NSR_DFA_SI_DD_LOCKBOX_PATH=C:\Program Files\DPSAPPS\common\lockbox" -a "NSR_SKIP_NON_BACKUPABLE_STATE_DB=TRUE" MSSQL:data_warehouse_s01
================================================================================
```
## Dependencies
- [PowerShell 7](https://github.com/powershell/powershell/releases)

## Pre-work:
- ### Update the $dms variable within the workflow script
    - name: The FQDN or IP address of the target PowerProtect Data Manager Server
    - lockbox: This path to the lockbox directory
    - retention: How long to retain the backup for in days
```
$dms = @(
    @{
        name = "dm-01.vcorp.local"
        lockbox = "C:\Program Files\DPSAPPS\common\lockbox"
        retention = 30
    }
)
```
## Usage:
### PS C:\social-media> .\get-ddbmsqlsv.ps1 -Database data_warehouse_s01 -FQDN sql-01.vcorp.local

# Workflow
The code will iterate over each PPDM instance defined within $dms and perform the following actions:
- Connect to the rest api
- Query for the protected database asset matching the filter critera
- Query for the associated protection policy
    - Parse out the target object from the backup objective
    - Note: This is the PowerProtect DD and stoage unit information
- Query for the storage system (PowerProtect DD) 
    - Note: We need this for the networking information
- Query for the storage unit information
- Query for the credentials
- Logoff of the REST API