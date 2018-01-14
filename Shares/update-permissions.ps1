<#

.SYNOPSIS

adds permissions through a folder structure.


.DESCRIPTION

can be used to ensure a specific group or user has rights to every folder under the root.


.PARAMETER path

starting path to begin the remediation. all folders and files underneath are affected.  mandatory.


.PARAMETER account

group or user that should have access to the folders and files.  it must be submitted in this format:
DOMAINSHORTNAME\grouporuser
mandatory.


.PARAMETER rights

type of permissions you want the user or group to have.  mandatory.


.EXAMPLE
give the domain admins access to all folders on D: drive.

poweshell.exe update-permissions.ps1 -path "D:\" -account "DOMAINSHORTNAME\domain admins" -rights "FullControl"

#>

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True)]
   [string]$path,
   [Parameter(Mandatory=$True)]
   [string]$account,
   [Parameter(Mandatory=$True)]
   [string]$rights
)

If ((Get-Module -ListAvailable -Name "NTFSSecurity") -eq $null) {
    Install-Module -Name NTFSSecurity -Force -Confirm:$False
}

#retrieve root folders
Try {
    $msg = "Retrieving recursive objects from root"
    Write-Verbose $msg

    $driveObjs = Get-ChildItem -Path $path -Recurse
} Catch {
    #do nothing
}

#do the needful
$missingPerms = @()
$msg = "Beginning permission checks and assignment"
Write-Verbose $msg
ForEach ($driveObj in $driveObjs) {
    $msg = "Checking path => " + ($driveObj.FullName)
    Write-Debug $msg

    $acl = (Get-Acl $driveObj.FullName).Access | ?{$_.IdentityReference -eq $account} | Select IdentityReference,FileSystemRights
    If ($acl -eq $null){
        Write-Debug "$account Doesn't have any permission on $driveObj `n"
        Add-NTFSAccess -Path ($driveObj.FullName) -Account $account -AccessRights $rights
    }
    Else {
        #do-nothing
    }

    #retest
    $acl = (Get-Acl $driveObj.FullName).Access | ?{$_.IdentityReference -eq $account} | Select IdentityReference,FileSystemRights
    If ($acl -eq $null) {
        $missingPerms += $driveObj
    }
}

$msg = $account + "Still does not have access to the following objects:"
Write-Verbose $msg
Write-Verbose $missingPerms
