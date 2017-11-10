<#


.SYNOPSIS

Updates the file share pathing in the registry.


.DESCRIPTION

Retrieves file share properties from the registry if the oldPathSnippet string is found in the share 
path and replaces that string with the newPathSnippet value.


.PARAMETER oldPathSnippet

the string portion of the path that you want to replace.  mandatory.


.PARAMETER newPathSnippet

the string portion that you will replace oldPathSnippet with.  mandatory.


.PARAMETER removePrinterShares

set to True if you want to remove printer shares from the registry.  default=False.

.PARAMETER runForReal

set to True if you want the script to alter the registry.  default=False.


.EXAMPLE
Replace "E:\" with "D:\new_location\" and remove all printer shares, test run only

poweshell.exe alter-sharepaths.ps1 -oldPathSnippet 'E:\' -newPathSnippet 'D:\new_location\' removePrinterShares $True -runForReal $True


.NOTES

I built this to clean up shares when I did I merged 3 file/print servers into a new server.  I exported and
imported the HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Shares registry key from old to new server, then 
ran this script to alter the share locations, pointing the shares to the new locs.

Server needs a reboot or restart of the server service.


#>

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True)]
   [string]$oldPathSnippet,
  [Parameter(Mandatory=$True)]
   [string]$newPathSnippet,
  [Parameter(Mandatory=$False)]
   [boolean]$removePrinterShares=$False,
  [Parameter(Mandatory=$False)]
   [boolean]$runForReal=$False
)

# set variables
$regKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Shares'
If ($oldPathSnippet.Substring($oldPathSnippet.Length-1) -eq '\' -and $newPathSnippet.Substring($newPathSnippet.Length-1) -ne '\') {
    $atLoc = 'setVariables.  '
    $outMsg = $atLoc + $oldPathSnippet + ' has a trailing \ and ' + $newPathSnippet + ' does not.  ADDING!'
    Write-Output $outMsg

    $newPathSnippet = $newPathSnippet + '\'
}

# retrieve properties
$atLoc = 'retrieveProperties.  '
$keyProperties = Get-ItemProperty $regKey
If ($keyProperties) {
    $outMsg = $atLoc + 'Retrieved share properties.'
    Write-Output $outMsg
    $keyProperties = $keyProperties | Get-Member -MemberType NoteProperty | ?{$_.Definition -like ('*System.String*')} | Select Name
} Else {
    $outMsg = $atLoc + 'No shares found.  EXITING!'
    Write-Output $outMsg
    Exit
}

#do the deed
ForEach ($keyProperty in $keyProperties) {
    $keyPropertyValue = Get-ItemPropertyValue -Path $regKey -Name $keyProperty.Name
    If ($keyPropertyValue -like '*Type=1*') {
        $atLoc = 'printerHandler.  '
        if ($removePrinterShares -eq $True) {
            $outMsg = $atLoc + $keyProperty.Name + ' is a printer.  REMOVING!'
            Write-Output $outMsg

            if ($runForReal) {
                $regSecKey = $regKey + '\Security'
                Remove-ItemProperty -Path $regSecKey -Name $keyProperty.Name
                Remove-ItemProperty -Path $regKey -Name $keyProperty.Name
            }
        } Else {
            $debugMsg = $atLoc + $keyProperty.Name + ' is a printer.  SKIPPING!'
            Write-Output $debugMsg
        }
    }

    If ($keyPropertyValue -like '*Type=0*') {
        $atLoc = 'pathHandler.  '
        $newKeyPropertyValue = @()
        ForEach ($line in $keyPropertyValue) {
            If ($line -like ('Path=' + $oldPathSnippet + '*') -and $line -notlike ('Path=' + $newPathSnippet + '*')) {
                $newLine = $line.replace($oldPathSnippet, $newPathSnippet)
                $outMsg = $atLoc + 'Replacing "' + $line + '" with new line "' + $newLine + '"'
                Write-Output $outMsg

                $newKeyPropertyValue += $newLine
            } Else {
                $newKeyPropertyValue += $line
            }
        If ($runForReal) {
            Set-ItemProperty -Path $regKey -Name $keyProperty.Name -Value $newKeyPropertyValue
        }
        }
    }
}
