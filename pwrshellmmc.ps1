# ################################################################################################
# ################################################################################################
# Script name - pwrshellmmc.ps1
#
# -----------
# -----------
# --Details--
# -----------
# -----------
# This is script that will utilize the NetApp Powershell toolkit cmdlets to make changes to the  
# Windows File Services environment.  It will ask a series of questions about the environment
# using the replies to build a command that will be passed to the Clustered ONTAP cluster to make
# changes to the cifs configuration.
#
#
# Initially the script checks to make sure it's being run as an Administrator
# It will error out if it is not.
#
#
# Running the script:
# -------------------
# There is a single parameter needed in order to successfully run the script.  The parameter will
# build a credential using a Powershell Module available from the following site:
#
# https://gist.github.com/cdhunt/5729126/download#
# https://www.automatedops.com/blog/2013/06/07/get-storedcredentials-module/
#
# The module needs to downloaded and saved to:
# 
# c:\users\<username>\documents\windowspowershell\modules\storedcredential
#
# It will need to be saved as a psm1 file named the same as the subdirectory below "modules".
# The windowspowershell and modules subdirs will likely need to be created.  The storedcredential
# subdirectory can be whatevername you want.  In the above path the psm1 file needs to be named 
# "storedcredential.psm1"
#
# This parameter would be passed at the cli when running the script. It will build a credential by
# using a customer written Powershell module installed from above:
#
# When you run the script the syntax is as follows:
#
# PS c:\> .\pwrshellmmc.ps1 <windows_cred_store_target_URI>
#
# For example, if I created a Windows Credential Manager entry titled "marctme" I would run the
# script as: 
# 
# PS c:\> .\pwrshellmmc.ps1 marctme
#
# See the script comments throughout the script for further details on how this works
#
#
# SCRIPT VERSION HISTORY
# ----------------------
#
# Date - 06/01/2015
# Script version 1.0
#
# Version 1.0 includes:
# -Add share
# -Remove share
# -include parameter for grabbing and storing credentials to connect to SVM using Windows Credential
#  Manager (Windows 7 and later)
#
# ###############################################################################################
# ###############################################################################################


#
# This section uses the optional parameter passed upon script run that will build and store a 
# credential in order to connect to the SVM to complete the tasks.
# 
# It sets the Powershell execution policy to bypass in order to allow the script to run 
# without being prompted with a security warning.  Please note that you will need to run
# the script in an environment that you have confirmed is secure.  The parameter $wincredstor
# is not optional, it is required.  The script will exit if you do not provide a Windows
# Credential Store target URI entry name.
#
# Please consult your own internal security requirements before using the script in production
# to ensure it meets your environments internal security requirements.
#
param(
[string]$wincredstor
)

if([string]::IsNullOrEmpty($wincredstor))
{
    write-host ""
    write-host "You must supply Windows credential manager target URI, for example:" -ForegroundColor Green
    write-host ""
    write-host "PS C:\data\scripts> .\pwrshellmmc.ps1 marctmesvm" -ForegroundColor Red
    write-host ""
    write-host "Where marctmesvm is an entry created in the local Windows clients" -ForegroundColor Green
    write-host "Windows Credential Store." -foregroundcolor green
    write-host ""
    write-host "For more details on Windows Credential Manager see the following:" -ForegroundColor Green
    write-host "http://windows.microsoft.com/en-us/windows7/what-is-credential-manager" -ForegroundColor Green
    write-host ""
    return
}

Set-ExecutionPolicy bypass
$svmcredstore = get-storedcredential $wincredstor

function Run-As 

{

# Checks to make sure script is run by an Admin

param([Switch]$Check)

$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()`

).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if ($Check) { return $IsAdmin }

if ($MyInvocation.ScriptName -ne "")

{

if (-not $IsAdmin)

{

try

{

$arg = "-file `"$($MyInvocation.ScriptName)`""

Start-Process "$psHome\powershell.exe" -Verb Runas -ArgumentList $arg -ErrorAction 'stop' 

}

catch

{

Write-Warning "Error - Failed to restart script with runas"

break

}

exit # Quit this session of powershell

}

}

else

{

Write-Warning "Error - Script must be saved as a .ps1 file first"

break

}

write-host "Script Running As Administrator" -foregroundcolor red

Write-host ""

}

#Launching run-as function

Run-as
 

#Cleaning screen

cls

#
# Start off by asking what tasks they are interested in completing
# In order to add additional tasks, add in additional write-host
# lines and then create a function to allow the option to be run
#

Write-host
Write-host "This script will allow you to:"
Write-host ""
Write-host "   **Add / Remove a share" -foregroundcolor white
write-host ""

Do {
Write-host "#####################################################################" -foregroundcolor Green
Write-host "#####################################################################" -foregroundcolor Green
Write-host ""
Write-host "Please select from the following options:" -foregroundcolor cyan
Write-host "Option 1: Add / Remove SMB Share" -foregroundcolor White
Write-host
Write-host ""
Write-host "#####################################################################" -foregroundcolor Green
Write-host "#####################################################################" -foregroundcolor Green
Write-host ""
$initoptions = Read-host "Please enter 1 (future options will be added for additional Windows File Services management)"

write-host

} until ($initoptions -eq "1")



##########################
# If they select option 1
# jump to here
##########################

if ($initoptions -eq 1)


{

#
# Add/Remove share
#
    Do { 
    
    Write-host "STARTING ADD/REMOVE SHARE PROCESS" -foregroundcolor CYAN
    write-host ""
    Write-host "Do you want to add or remove an SMB share?" -foregroundcolor green
    $addremoveshare = read-host "Please enter Add or Remove"


    Write-host 
    } until ($addremoveshare -eq "add" -or $addremoveshare -eq "remove")


    #
    # Using Powershell switch statement to keep from having a large if/else series of statements
    # It is comparing the values for $add or $remove
    # 
    # Requires that user type in add or remove or the above will loop continuing to ask the use to enter
    # add or remove.  The switch statement is a compare of the value of the response to the available "functions" below it.
    #
    # Only valid responses are: add or remove
    # 
    #
    switch ($addremoveshare)
        {
          add{
          
          
                          DO {
                          #
                          # Requests the IP of an SVM management LIF on a node in the cDOT cluster that can accept the command
                          #
                          DO{
                          Write-host
                          Write-host "Enter in an SVM management LIF IP or hostname?" -foregroundcolor Green
                          $svmip = Read-Host "Enter a management LIF IP or hostname for the SVM where the share will reside"

                          if ($svmip -eq ""){write-host "error:Please enter in LIF details, cannot be blank" -foregroundcolor Red}
                         
                          Write-host

                          } while  ($svmip -eq "" -or $svmip -eq $NULL)
                          
                          Write-host                   
                      
                          #
                          # Connect to the SVM using the credential details pulled from 
                          # Windows Credential Manager
                          #
                          Connect-NcController $svmip -Credential $svmcredstore | format-table -property name,version | out-null                    
                          #
                          # Requests the name of the SVM where the share is to be created
                          #
                          DO {
                          Write-host
                          Write-host "What is the name of the SVM that will contain the share?" -foregroundcolor Green
                          $svmname = Read-Host "Enter the name of the SVM that will house the share"

                          if ($svmname -eq ""){write-host "error:Please enter in SVM name, cannot be blank" -foregroundcolor Red}
                         
                          Write-host

                          } while ($svmname -eq "" -or $svmname -eq $NULL)

                          #
                          #
                          # This section asks for the share name.  The entry cannot be blank or will loop back asking for value
                          #
                          Write-host

                          Write-host "What is the share name you want to create?" -foregroundcolor Green

                          $newshare= Read-host "Please type in share name"

                          if ($newshare -eq "") {write-host "error:Please enter in a share name, cannot be blank" -foregroundcolor Red}; if ($newshare -eq $NULL) {write-host "error: Please enter in a share name, cannot be blank" -foregroundcolor Red}

                          write-host

                          } while ($newshare -eq "" -or $newshare -eq $NULL)
                        
                          #
                          # This section asks for the SVM volume junction path (or mount path).  The entry cannot be blank or will loop back asking for value
                          #

                          Do {
                          ##################################################################################
                          ###
                          ### This section will display just the available volumes and their junction paths
                          ### so that the user can select the volume junction for the share.
                          ### It does require that the user be authenticated to the SVM first in order to 
                          ### pull the data.
                          ###
                          ##################################################################################
                          
                          write-host "******************************************************************************" -backgroundcolor Blue
                          write-host " This is a list of volumes and their junction paths available on $svmip " -foregroundColor white
                          write-host "******************************************************************************" -backgroundcolor Blue

                          #
                          # This will query the connected to SVM for the list of volumes and their junction paths
                          #

                          $jpquery = get-ncvol -template
                          Initialize-NcObjectProperty $jpquery vserver -WarningAction SilentlyContinue >$NULL
                          $jpquery.vserver = $svmname
                          get-ncvol -Query $jpquery | select name,junctionpath | ft -AutoSize
                          
                          Write-host
                          Write-host "Please enter a JunctionPath returned from the above output" -ForegroundColor Green
                          $volmount = Read-Host "Enter in the junction path?"

                          if ($volmount -eq ""){write-host "error:Please enter in the junction path, cannot be blank" -foregroundcolor Red}; if ($volmount -eq $NULL) {write-host "error: Please enter in the junction path, cannot be blank" -foregroundcolor Red}

                          Write-host

                          } while ($volmount -eq "" -or $volmount -eq $NULL)
                             
                          #
                          # Get the date and time for reporting a conclusion
                          #
                          $stime = get-date 

                          # Create the share and set initial permissions on the share
                         
                          add-nccifsshare -name $newshare -path $volmount -vservercontext $svmname 
                          
                          write-host "$stime"
                          write-host "New share create on SVM $svmname with share name of $newshare"

                          Read-host "Press the ENTER key to close..."                         
                    
          }
          
          remove{
                          #
                          # Requests the IP of a management LIF or the hostname associated with the 
                          # SVM management for the SVM in cDOT
                          #
                          DO{
                          Write-host
                          Write-host "Enter in an SVM management LIF IP or hostname?" -foregroundcolor Green
                          $svmip = Read-Host "Enter a management LIF IP or hostname for the SVM where the share will reside"

                          if ($svmip -eq ""){write-host "error:Please enter in LIF details, cannot be blank" -foregroundcolor Red}
                         
                          Write-host   
                          } while ($svmip -eq "" -or $svmip -eq $NULL)
                         
                          #
                          # Connect to the SVM provided when prompted above. It will
                          # use the credential retrieved from the Windows Credential Manager
                          #
                          Connect-NcController $svmip -credential $svmcredstore | format-table -property name,version | out-null

                          #
                          # Requests the name of the SVM where the share is to be removed
                          #
                          DO {
                          Write-host
                          Write-host "What is the name of the SVM that houses the share to be removed?" -foregroundcolor Green
                          $svmname = Read-Host "Enter the name of the SVM that houses the share"

                          if ($svmname -eq ""){write-host "error:Please enter in SVM name, cannot be blank" -foregroundcolor Red}
                         
                          Write-host

                          } while ($svmname -eq "" -or $svmname -eq $NULL)
          
                          
                          #                          
                          # Displays the name of the available shares associated with the SVM
                          # Request the name of the share to remove
                          #
                          DO{

                          write-host "****************************************************" -backgroundcolor blue -foregroundcolor white
                          Write-host " These are the list of shares hosted on $svmname    " -foregroundcolor white
                          write-host "****************************************************" -backgroundcolor blue -foregroundcolor white
                          get-nccifsshare | format-table -Property cifsserver,sharename 
                                                    
                          
                          Write-host "Enter in the name of the share to remove?" -foregroundcolor Green
                          $delshare = Read-Host "Type in the name of the share to delete"

                          if ($delshare -eq ""){write-host "error:Please enter in LIF details, cannot be blank" -foregroundcolor Red}
                         
                          Write-host

                          } while  ($delshare -eq "" -or $delshare -eq $NULL)                 
                   
                          
                          #
                          # Get the date and time for reporting a conclusion
                          #
                          $stime = get-date 

                          # Create the share and set initial permissions on the share
                          remove-nccifsshare -name $delshare -vservercontext $svmname 
                          write-host $stime
                          write-host "Share deleted from SVM" $svmname "with share name of" $delshare

                          Read-host "Press the ENTER key to close..."                 
          
          }
          
        }
        
}
