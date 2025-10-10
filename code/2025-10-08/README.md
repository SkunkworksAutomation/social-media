# Start backups serially on assets within a protection policy
## Dependencies
- [PowerShell 7](https://github.com/powershell/powershell/releases)

## Pre-work:
- ### Update the $dms variable within the workflow script
    - name: The FQDN or IP address of the target PowerProtect Data Manager Server
    - policy: The name of the protection policy to pull the asset list from
    - characters: an array of ints which will determine the starting and ending position for your application role
```
$dms = @(
    @{
        name = "dm-01.vcorp.local"
        policy= "YourProtectionPolicyName"
        characters = @(5,6,7)
    }
)
```
## How the name parsing works...
```
# This is used to evaluate the character positions that are parsed by regex
@{l="role";e={
    ($_.name).Substring($chars[0]-1,$chars.length)
}}
# Example name: myvmdbsdc-01
# We want to capture: dbs
# $dm.characters = @(5,6,7)
# [array]$chars = $dm.characters
# $chars[0]-1, or element[0].value-1: 5-1 = 4
# $chars.length = 3

Applied to this example, 0 starts on the left side of the first character in the name
01234567891011
    myvmdbsdc-01

The 4th position would be to the right of the 2nd m.
Now we count out $chars.length positions, 3 in this example and get dbs

Now we match that against our regex for the application role to see if we are going to backup this vm's role 
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