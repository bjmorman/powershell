<#

.SYNOPSIS

updates drive mappings from one host to another.


.DESCRIPTION

can be used as a login script for users who have hard-coded drive mappings outside of group policies.


.PARAMETER domain

active directory domain used to construct the fqdn for oldHost/newHost.  mandatory.


.PARAMETER oldHost

short name of the host you want to remove the mapping for.  mandatory.


.PARAMETER newHost

shortname of the host you want to remap to.  mandatory.


.PARAMETER reMap

set to True if you want to actively remap from oldHost to newHost.  default=False.


.PARAMETER logOutput

set to True if you want to log the affected drive mappings to a central location.  default=False.


.PARAMETER logOutputPath

full unc path to a folder everyone has r/w access to in order to write affected drive mappings.


.EXAMPLE
remap drives from old-fs to new-fs servers on example.net domain.

poweshell.exe remap-drives.ps1 -domain 'example.net' -oldHost 'old-fs' -newHost 'new-fs' -reMap $True -logOutput $True -logOutputPath '\\log\path\'


#>

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True)]
   [string]domain,
  [Parameter(Mandatory=$True)]
   [string]oldHost,
  [Parameter(Mandatory=$True)]
   [string]newHost,
  [Parameter(Mandatory=$False)]
   [boolean]reMap=$False,
  [Parameter(Mandatory=$False)]
   [boolean]logOutput=$False,
  [Parameter(Mandatory=$False)]
   [string]logOutputPath
)

# TODO: check for open files
# TODO: error handling

Function Get-Mappings {
    param ( $oldHostShort,
            $oldHostLong )

    $mappings = @()
    $mappings += Get-PSDrive -PSProvider FileSystem | ?{$_.DisplayRoot -like $oldHostShort -or $_.DisplayRoot -like $oldHostLong} | Select Name, Root, DisplayRoot
    $mappings += Get-PSDrive -PSProvider FileSystem | ?{$_.Root -like $oldHostShort -or $_.Root -like $oldHostLong} | Select Name, Root, DisplayRoot

    Return $mappings
}

Function Parse-Mappings {
    param ( $mappings,
            $oldHostShort,
            $oldHostLong,
            $newHostShort,
            $newHostLong )

    $parsedMappings = @()
    $mappings | % {
        $path = $null
        $newPath = $null

        If ($_.Root -like $oldHostShort -or $_.Root -like $oldHostLong) {
            $path = $_.Root
            $newPath = ($_.Root).replace($oldHost, $newHost)
        } Else {
            $path = $_.DisplayRoot
            $newPath = ($_.DisplayRoot).replace($oldHost, $newHost)
        }

        $pscoMapping = [PSCustomObject]@{
            drive    = $_.Name
            oldPath  = $path
            newPath  = $newPath
        }
    
        $parsedMappings += $pscoMapping
    }
    return $parsedMappings
}

Function Log-Output {
    param ( $drives,
            $logOutputPath )

    $fileName = (Invoke-Expression whoami).split("\")[1] + ".csv"
    $filePath = $logOutputPath + $fileName
    $drives | Export-Csv -Path $filePath -Force
}

Function Re-Map {
    param ( $drives )

    ForEach ($drive in $drives) {
        #out with the old
        $delCmd = "net use " + $drive.drive + ": /DELETE /YES"
        Invoke-Expression $delCmd | Out-File c:\1.txt

        #in with the new
        $newCmd = "net use " + $drive.drive + ": " + $drive.newPath
        Invoke-Expression $newCmd | Out-File c:\2.txt
    }
}

# main
# retrieve current mappings
$oldHostShort = "\\" + $oldHost + "\*"
$oldHostLong = "\\" + $oldHost + "." + $domain + "\*"
$newHostShort = "\\" + $newHost + "\*"
$newHostLong = "\\" + $newHost + "." + $domain + "\*"

$currentMappings = $Null
$drives = $Null
$currentMappings = Get-Mappings $oldHostShort $oldHostLong

if ($currentMappings) {
    # do the deed
    $drives = Parse-Mappings $currentMappings $oldHostShort $oldHostLong $newHostShort $newHostLong

    if ($logOutput) {
        Log-Output $drives $logOutputPath
    }

#    If ($reMap) {
#        Re-Map $drives
#    }
} Else {
    # do nothing
}

