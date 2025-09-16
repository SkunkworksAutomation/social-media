# PowerProtect Data Manager Automation Examples
## Published on social media

<a href="https://skunkworksautomation.github.io/social-media" target="_blank">EXAMPLES DASHBOARD</a>

This code repository examples are built on PowerShell 7. There two components to each example:
- ## PowerShell 7 Module:
**[skunkworks.dm.prototype.psm1](https://github.com/SkunkworksAutomation/social-media/blob/main/code/skunkworks.dm.prototype.psm1)**

The module consists of four methods that do the heavy lifting so you don't have to:
- **connect-dmapi**
    - Securing the credentials in a credentials file where the password word is encrypted via the windows data protection api
    - Note: The credentials file is NOT portable. 
    - Note: To decrypt the password the folowing conditions MUST be met
        - The file must reside on the computer it was created on
        - The decrypt process must be run under the user context it was created with
    - Requests the bearer token
    - Uses the bearer token on subsequent REST API calls
    - Refreshes the bearer token (if you run operations that exceed the tokens TTL, think monitoring a long running job)
```
 # Example:
 # Connect to the rest api
    connect-dmapi `
    -Server $dm.name `
    -Port 8443 `
    -Version 2
```

- **get-dm**
    - Includes random access paging
    - Allows you define the endpoint and version to help future proof your workflow scripts
```
# Example
# Using the getter method with a filter criteria
$Filters = @(
    "name eq `"$($dm.policy)`""
)
$Endpoint = "protection-policies"
$query2 = get-dm `
    -Endpoint "$($Endpoint)?filter=$($Filters)" `
    -Version 3
```

- **set-dm**
    - Allows you to define the endpoint, version, method (PUT, POST, PATCH)
    - Note: The DELETE http method was intentionally omitted, add it at your own risk

```
# Example
$Body = [ordered]@{
    # The properties of your request body would be defined here
    # ...
}
$action1 = set-dm `
    -Endpoint "protections" `
    -Method POST `
    -Version 3 `
    -Body $Body `
    -Message "Starting ad hoc backup for $($query2.name)"
```
- **disconnect-dmapi**
    - Destroys the bearer token and $global:dmAuthObject variable

```
# Example
# Disconnect from the rest api
disconnect-dmapi
```
- ## Workflow Script:
The workflow scripts will be contained within a folder on the date they were published in addition to any relevant documentation.
They will import the module so you, the automation engineer, can focus on process and not have to deal in the minutia