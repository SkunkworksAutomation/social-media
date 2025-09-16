# Social Media
I'm currently in the process of setting this up. Check back later!

This code repository examples are built on PowerShell 7. There two components to each example:
- ## The PowerShell 7 module:
**[skunkworks.dm.prototype.psm1](https://github.com/SkunkworksAutomation/social-media/blob/main/code/skunkworks.dm.prototype.psm1)**

The module consists of four methods that do the heavy lifting so you don't have to:
- **connect-dmapi**
    - Securing the credentials in a credentials file where the password word is encrypted via the windows data protection api
    - The credentials file is NOT portable. 
    - Note: To decrypt the password the folowing conditions MUST be met
        - The file must reside on the computer it was created on
        - The decrypt process must be run under the user context it was created with
    - Requests the bearer token
    - Uses the bearer token on subsequent REST API calls
    - Refreshes the bearer token (if you run operations that exceed the tokens TTL, think monitoring a long running job)
- **get-dm**
    - Includes random access paging
    - Allows you define the endpoint and version to help future proof your workflow scripts
- **set-dm**
    - Allows you to define the endpoint, version, method (PUT, POST, PATCH)
    - Note: The DELETE http method was intentionally omitted, add it at your own risk
- **disconnect-dmapi**
    - Destroys the bearer token and $global:dmAuthObject variable
