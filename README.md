# README #


### What is this repository for? ###

Generic location to store quick powershell scripts.


### alter-sharepaths.ps1 ###
Updates the file share pathing in the registry.  Useful when importing shares from other servers and the destination disk paths are not the same.

### remap-drives.ps1 ###
Remaps drive for one host to another host.  Can be used as a login script for users who have hard-coded drive mappings outside of group policies.

### update-permissions.ps1 ###
Ensures a specific group or user has rights set to every folder under the defined root folder.