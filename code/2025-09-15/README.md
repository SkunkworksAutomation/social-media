# Backing up VMware virtual machine templates
## Dependencies
- [PowerShell 7](https://github.com/powershell/powershell/releases)
- [VCF.PowerCLI](https://www.powershellgallery.com/packages/VCF.PowerCLI/9.0.0.24798382)

## Pre-work:
- ### VMWare
    - Ensure all vm templates are in the same folder in the target vCenter
    - NOTE: The folder name, within vcenter, will need to be the same across all vcenters managed by the target instance of PowerProtect Data Manager

- ### PowerProect Data Manager
    - Create a protection policy for virtual machines, this will be for the templates, you can set schedule to once a year.
    - Create a protection rule for that policy we just created pointed at the vcenter template folder.

- ### Updae the $dms variable within the workflow script
    - name: The FQDN or IP address of the target PowerProtect Data Manager Server
    - policy: The virtual machine protection policy, configured with a protection rule to grab the virtual machines, contained with the VMware templates folder.
    - folder: The name of the templates folder within the downstream managed vCenters. The folder name must be the same across all vCenters managed by PowerProtect Data Manager.
```
$dms = @(
@{
        name = "192.xxx.xxx.xx1"
        policy = "VM Policy Templates1"
        folder = "Templates"
    },
@{
        name = "192.xxx.xxx.xx2"
        policy = "VM Policy Templates2"
        folder = "Templates"
    }
)
```
## Workflow
The code will iterate over each PPDM instance defined within $dms and perform the following actions:
- Connect to the rest api
- Query for the attached vcenters
- Iterate over the results from the vCenter query
    - Connect to the vCenter via PowerCLI
    - Query for ALL templates
    - Iterate over the list of templates
        - Convert the template to a VM
        - Query PPDM, at a 10 second interval, until the VMs are in a protectable state
        - Note: Once the vms are protectable the rule will automatically drop the vms into the policy we created above
        - Query for the protection policy name (defined in the $dms config above)
        - Build the request body
        - Start the backup
        - Monitor the backup until complete
        - Convert the vms back into templates
        - Move on to the next vcenter if there are more, or the next ppdm server if there aren't any more managed vcenters for this ppdm instance