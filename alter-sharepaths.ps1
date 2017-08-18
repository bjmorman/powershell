<#

.SYNOPSIS

Updates the file share pathing in the registry.


.DESCRIPTION

Retrieves file share properties from the registry if the old_path parameter is found with the new_path value.


.PARAMETER old_path

the string portion of the path that you want to replace.  mandatory.


.PARAMETER new_path

the string portion that you will replace old_path with.  mandatory.


.PARAMETER remove_printer_shares

set to True if you want to remove printer shares from the registry.  default=False.

.PARAMETER run_for_real

set to True if you want the script to alter the registry.  default=False.


.EXAMPLE
Replace "E:\" with "D:\new_location\" and remove all printer shares, test run only

poweshell.exe alter-sharepaths.ps1 -old_path 'E:\' -new_path 'D:\new_location\' remove_printer_shares='True'


.NOTES

I built this to clean up shares when I did I merged 3 file/print servers into a new server.  I exported and
imported the HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Shares registry key from old to new server, then 
ran this script to alter the share locations.


#>

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True)]
   [string]$old_path,
  [Parameter(Mandatory=$True)]
   [string]$new_path,
  [Parameter(Mandatory=$False)]
   [boolean]$remove_printer_shares=$False,
  [Parameter(Mandatory=$False)]
   [boolean]$run_for_real=$False
)

# set variables
$reg_key = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Shares'
If ($old_path.Substring($old_path.Length-1) -eq '\' -and $new_path.Substring($new_path.Length-1) -ne '\') {
    $at_loc = 'setVariables.  '
    $outMsg = $at_loc + $old_path + ' has a trailing \ and ' + $new_path + ' does not.  ADDING!'
    Write-Output $outMsg

    $new_path = $new_path + '\'
}

# retrieve properties
$at_loc = 'retrieveProperties.  '
$key_properties = Get-ItemProperty $reg_key
If ($key_properties) {
    $outMsg = $at_loc + 'Retrieved share properties.'
    Write-Output $outMsg
    $key_properties = $key_properties | Get-Member -MemberType NoteProperty | ?{$_.Definition -like ('*System.String*')} | Select Name
} Else {
    $outMsg = $at_loc + 'No shares found.  EXITING!'
    Write-Output $outMsg
    Exit
}

#do the deed
ForEach ($key_property in $key_properties) {
    $key_property_value = Get-ItemPropertyValue -Path $reg_key -Name $key_property.Name
    If ($key_property_value -like '*Type=1*') {
        $at_loc = 'printerHandler.  '
        if ($remove_printer_shares -eq $True) {
            $outMsg = $at_loc + $key_property.Name + ' is a printer.  REMOVING!'
            Write-Output $outMsg

            $reg_sec_key = $reg_key + '\Security'
            Remove-ItemProperty -Path $reg_sec_key -Name $key_property.Name
            Remove-ItemProperty -Path $reg_key -Name $key_property.Name
        } Else {
            $debugMsg = $at_loc + $key_property.Name + ' is a printer.  SKIPPING!'
            Write-Output $debugMsg
        }
    }

    If ($key_property_value -like '*Type=0*') {
        $at_loc = 'pathHandler.  '
        $new_key_property_value = @()
        ForEach ($line in $key_property_value) {
            If ($line -like ('Path=' + $old_path + '*') -and $line -notlike ('Path=' + $new_path + '*')) {
                $new_line = $line.replace($old_path, $new_path)
                $outMsg = $at_loc + 'Replacing "' + $line + '" with new line "' + $new_line + '"'
                Write-Output $outMsg

                $new_key_property_value += $new_line
            } Else {
                $new_key_property_value += $line
            }
        If ($run_for_real) {
            Set-ItemProperty -Path $reg_key -Name $key_property.Name -Value $new_key_property_value
        }
        }
    }
}
