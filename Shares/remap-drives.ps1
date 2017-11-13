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
   [string]$domain,
  [Parameter(Mandatory=$True)]
   [string]$oldHost,
  [Parameter(Mandatory=$True)]
   [string]$newHost,
  [Parameter(Mandatory=$False)]
   [boolean]$reMap=$False,
  [Parameter(Mandatory=$False)]
   [boolean]$logOutput=$False,
  [Parameter(Mandatory=$False)]
   [string]$logOutputPath
)

# TODO: check for open files
# TODO: error handling

Function Get-Mappings {
    param ( $oldHostShort,
            $oldHostLong )

    # using Get-WmiObject instead of Get-PSDrive due to powershell version differences and inconsistent results
    $mappings += Get-WmiObject Win32_MappedLogicalDisk | ?{$_.ProviderName -like $oldHostShort -or $_.ProviderName -like $oldHostLong} |Select Name, ProviderName

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

        If ($_.ProviderName -like $oldHostShort -or $_.ProviderName -like $oldHostLong) {
            $path = $_.ProviderName
            $newPath = ($_.ProviderName.ToLower()).replace($oldHost.ToLower(), $newHost.ToLower())

            $props = @{
                drive = $_.Name
                oldPath = $path
                newPath = $newPath
            }
            $coMapping = New-Object PSObject -Property $props
        }

        # does not work in older powershell versions
        #$coMapping = [PSCustomObject]@{
        #    drive    = $_.Name
        #    oldPath  = $path
        #    newPath  = $newPath
        #}
    
        $parsedMappings += $coMapping
    }
    return $parsedMappings
}

Function Validate-Mappings {
    param ( $parsedMappings )

    # some mappings can falsely appear in Get-WmiObject Win32_MappedLogicalDisk,
    # this removes them
    $validatedMappings = @()
    $netUseOutput = Invoke-Expression "net use"
    $parsedMappings | % {
        if ($netuseOutput | Select-String $_.drive) {
            $validatedMappings += $_
        }
    }
    Return $validatedMappings
}

Function Log-Output {
    param ( $parsedMappings,
            $logOutputPath )

    $fileName = (Invoke-Expression whoami).split("\")[1] + ".txt"
    $filePath = $logOutputPath + $fileName
    $parsedMappings | Out-File -FilePath $filePath -Force
}

Function Re-Map {
    param ( $parsedMappings )

    ForEach ($drive in $parsedMappings) {
        #out with the old
        $delCmd = "net use " + $drive.drive + ": /DELETE /YES"
        Invoke-Expression $delCmd

        #in with the new
        $newCmd = "net use " + $drive.drive + ": " + $drive.newPath
        Invoke-Expression $newCmd
    }
}

# main
# retrieve current mappings
$oldHostShort = "\\" + $oldHost.ToLower() + "\*"
$oldHostLong = "\\" + $oldHost.ToLower() + "." + $domain + "\*"
$newHostShort = "\\" + $newHost.ToLower() + "\*"
$newHostLong = "\\" + $newHost.ToLower() + "." + $domain + "\*"

$currentMappings = $Null
$parsedMappings = $Null
$currentMappings = Get-Mappings $oldHostShort $oldHostLong

if ($currentMappings) {
    # do the deed
    $parsedMappings = Parse-Mappings $currentMappings $oldHostShort $oldHostLong $newHostShort $newHostLong
    $validatedMappings = Validate-Mappings $parsedMappings

    if ($logOutput) {
        Log-Output $validatedMappings $logOutputPath
    }

#    If ($reMap) {
#        Re-Map $validatedMappings
#    }
} Else {
    # do nothing
}

