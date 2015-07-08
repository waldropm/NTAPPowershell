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
# There are two parameters needed in order to successfully run the script.  The 1st parameter will
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
# PS c:\> pwrshellmmc.ps1 <windows_cred_store_target_URI> <svmMgmt_Lif_IP_Hostname>
#
# For example, if I created a Windows Credential Manager entry titled "marctme" and was conneting
# to the "tenantA" svm I would run the script as: 
# 
# PS c:\> pwrshellmmc.ps1 marctme tenantA
#
# See the comments throughout the script for further details on how the script works
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
# -Add acl
# -Remove acl
# -include parameter for grabbing and storing credentials to connect to SVM using Windows Credential
#  Manager (Windows 7 and later)
#
# Date - 06/05/2015
# Script version 1.1
# 
# Version 1.1 includes:
# -added connectnc function to build re-usable code to insert for the various workflows for SVM logins
# -added option to manage share ACLs
# -changed the code to require two parameters when running the script: credential manager and SVMName
#
# Version 1.2 includes:
# -added in ability to view and close CIFS sessions
#
# ###############################################################################################
# ###############################################################################################


#
# This builds two required parameters that are passed via the CLI when
# running the script.  
#
param(
[Parameter(Position = 1)]
[string]
[ValidateNotNullOrEmpty]
$wincredstor,
[Parameter(Position = 2)]
[string]
[ValidateNotNullOrEmpty]
$svmmgtlif
     )

#
# Commented out this section and used a verifier in the paramter statement above
# It will confirm that the required parameters are provided
#
#if([string]::IsNullOrEmpty($wincredstor))
#
#{
#    write-host ""
#    write-host "You must supply Windows credential manager target URI, for example:" -ForegroundColor Green
#    write-host ""
#    write-host "PS C:\data\scripts> .\pwrshellmmc.ps1 marctmesvm" -ForegroundColor Red
#    write-host ""
#    write-host "Where marctmesvm is an entry created in the local Windows clients" -ForegroundColor Green
#    write-host "Windows Credential Store." -foregroundcolor green
#    write-host ""
#    write-host "For more details on Windows Credential Manager see the following:" -ForegroundColor Green
#    write-host "http://windows.microsoft.com/en-us/windows7/what-is-credential-manager" -ForegroundColor Green
#    write-host ""
#    return
#}


#
# Building credential function.  It will use (2) parameters passed from the CLI and noted above in the script
# The function will be called later in the script based on the option selected.  This will keep from having
# to write separate connect-nccontroller entries in other sections
#
# It sets the Powershell execution policy to bypass in order to allow the script to run 
# without being prompted with a security warning.  Please note that you will need to run
# the script in an environment that you have confirmed is secure.  The parameter $wincredstor
# is not optional, it is required.  The script will exit if you do not provide a Windows
# Credential Store target URI entry name.
#
# Please consult your own internal security requirements before using the script in production
# to ensure it meets your environments internal security requirements.
Set-ExecutionPolicy bypass
$svmcredstore = get-storedcredential $wincredstor

#
# Function created to call when connect to the SVM is necessary
# Easier than extra coding of the connect-nccontroller cmdlet
#
function Connectnc
{
Connect-NcController $svmmgtlif -Credential $svmcredstore | format-table -property name,version | out-null
}

#
# Checks to make sure script is run by an Admin
#
function Run-As 

{

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
Write-host "   **Add / Remove / Modify SMB Share ACL" -foregroundcolor white
Write-host "   **View / Close SMB Client sessions" -foregroundcolor white
write-host ""

Do {
Write-host "#####################################################################" -foregroundcolor Green
Write-host "#####################################################################" -foregroundcolor Green
Write-host ""
Write-host "Please select from the following options:" -foregroundcolor cyan
Write-host "Option 1: Add / Remove SMB Share" -foregroundcolor White
Write-host "Option 2: New / Remove / Modify SMB Share ACL" -foregroundcolor white
Write-host "Option 3: View / Close SMB Client Sessions" -foregroundcolor white
Write-host ""
Write-host ""
Write-host "#####################################################################" -foregroundcolor Green
Write-host "#####################################################################" -foregroundcolor Green
Write-host ""
$initoptions = Read-host "Please enter 1, 2 or 3"

write-host

} until ($initoptions -eq "1" -or $initoptions -eq "2" -or $initoptions -eq "3")




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
                          # Calling the connectnc function
                          # This will connect to the SVM provided when the script was started
                          #       
                          connectnc
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
                          write-host " This is a list of volumes and their junction paths available on $svmname" -foregroundColor white
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
                          # Connect to SVM function
                          # Calling the connectnc function to establish connection to the SVM
                          #
                          connectnc

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

##########################
# If they select option 2
# jump to here
##########################
if ($initoptions -eq 2)

{

#
#  Add, Remove or Modify and existing share ACL
#
 Do { 
    
    #launching the connc function which will connect to the SVM
    Connectnc

    Write-host "STARTING ADD/REMOVE/MODIFY SHARE PERMISSIONS" -foregroundcolor CYAN
    write-host ""
    Write-host "Do you want to add(new), remove or modify(existing) share permissions?" -foregroundcolor green
    $armacl = read-host "Please enter add, remove or modify"

    Write-host 
    } until ($armacl -eq "add" -or $armacl -eq "remove" -or $armacl -eq "modify")

    #
    # Using the switch Powershell statement to keep from having nested and confusing if statements
    #

    switch ($armacl)
        {
            add{
                          #
                          # Add NEW ACL entry to the share
                          #  
                          DO{

                          # Obtaining CIFS Server name to pull list CIFS shares
                          write-host
                          write-host "What is the name of the CIFS server where the share resides?" -ForegroundColor Green
                          $cdotcifssvr = Read-Host "Enter the CIFS server name"

                          if ($cdotcifssvr -eq ""){write-host "error:Please enter in the CIFS server, cannot be blank" -foregroundcolor Red}

                          #Pull list of sharenames and their path
                          write-host ""
                          write-host "####################################################" -ForegroundColor Green                          
                          write-host "This is a list of shares on CIFS server:" -foregroundcolor White -NoNewline; write-host "  $cdotcifssvr"
                          write-host "####################################################" -ForegroundColor Green

                          $aclchange = Get-NcCifsShare -Template
                          $aclchange.cifsserver = "$cdotcifssvr"
                          Get-NcCifsShare -Query $aclchange | select sharename,path | ft -AutoSize
                          
                          Write-host
                          Write-host "What is the name of the share to add the ACL to?" -foregroundcolor Green
                          $csharename = Read-Host "Enter the name of the share"

                          if ($csharename -eq ""){write-host "error:Please enter in the share name, cannot be blank" -foregroundcolor Red}
                         
                          Write-host

                          } while ($csharename -eq "" -or $csharename -eq $NULL)                         
                             
                          #
                          # This section asks for a username or group to add to the ACL.
                          #
                          DO{
                          Write-host
                          Write-host "What user or group are you adding to the SHARE ACL?" -foregroundcolor Green
                          #$grpusername = Read-Host "Enter in the user or group name in the format of domainName\userName or domainName\groupName or everyone"
                          
                          [array]$grpusername = (Read-Host “User or Group (separate with comma)”).split(“,”)
                          
                          if ($grpusername -eq ""){write-host "error:Please enter in a user or group name, cannot be blank" -foregroundcolor Red}; if ($grpusername -eq $NULL) {write-host "error: Please enter in a user or group name, cannot be blank" -foregroundcolor Red}

                          Write-host
                          } while ($grpusername -eq "" -or $grpusername -eq $NULL)
    
          
                          # 
                          # Requests the type of permissions to set on the share itself.  There are only 3 options, all will be listed in the command
                          # 
                          DO {
                          Write-host
                          Write-host "What permission do you want to set for the user or group?" -foregroundcolor Green
                          $newshareperms = Read-Host "Enter the permissions: no_access, read, change or full_control"
                          
                          if ($newshareperms -eq ""){write-host "error:Please enter in permissions, cannot be blank" -foregroundcolor Red}
                           
                          Write-host
                          } until ($newshareperms -eq "no_access" -or $newshareperms -eq "read" -or $newshareperms -eq "change" -or $newshareperms -eq "full_control")  
                          
                          
                                                       
                          #
                          # Requests the name of the SVM where the share is to be created
                          #
                          DO {
                          Write-host
                          Write-host "What is the name of the Data SVM that houses the share to be removed?" -foregroundcolor Green
                          $svmname = Read-Host "Enter the name of the SVM that houses the share"

                          if ($svmname -eq ""){write-host "error:Please enter in SVM name, cannot be blank" -foregroundcolor Red}
                         
                          Write-host

                          } while ($svmname -eq "" -or $svmname -eq $NULL)                                    
                          
                          #
                          # Get the date and time for reporting a conclusion
                          #
                          $stime = get-date 

                          # Create the share and set initial permissions on the share
                          #Connect-NcController $svmip -credential $adminuser | format-table -property name,version | out-null                                                                   

                          
                          foreach ($userorgroup in $grpusername)
                          {
                          add-nccifsshareacl -share $csharename -userorgroup $userorgroup -permission $newshareperms -vservercontext $svmname
                          }                                                

                          write-host $stime
                          write-host "New share ACL added on share" $csharename "on SVM" $svmname "for the following user or group" $grpusername

                          Read-host "Press the ENTER key to close..."         
          
            }
          
          
          remove{
                         #
                         # Remove ACL entry on a share
                         #  
                         DO{


                          # Obtains the CIFS server name to use it later to pull list of shares for that CIFS server
                          write-host
                          write-host "What is the name of the CIFS server where the share resides?" -ForegroundColor Green
                          $cdotcifssvr = Read-Host "Enter the CIFS server name"

                          if ($cdotcifssvr -eq ""){write-host "error:Please enter in the CIFS server, cannot be blank" -foregroundcolor Red}

                          write-host ""
                          write-host "####################################################" -ForegroundColor Green                          
                          write-host "This is a list of shares on CIFS server:" -foregroundcolor White -NoNewline; write-host "  $cdotcifssvr"
                          write-host "####################################################" -ForegroundColor Green

                          #Pulls just the list of shares and their paths
                          $aclchange = Get-NcCifsShare -Template
                          $aclchange.cifsserver = "$cdotcifssvr"
                          Get-NcCifsShare -Query $aclchange | select sharename,path | ft -AutoSize
                          ###New stuff end 0504_1335
                          
                         Write-host
                         Write-host "What is the name of the share to REMOVE the ACL on?" -foregroundcolor Green
                         $csharename = Read-Host "Enter the name of the share"

                         
                         if ($csharename -eq ""){write-host "error:Please enter in the share name, cannot be blank" -foregroundcolor Red}
                         
                         Write-host

                         } while ($csharename -eq "" -or $csharename -eq $NULL)                                       
          
          
                         #
                         # This section asks for a username or group to remove from to the share ACL.
                         #
                         DO{                         

                         # Obtains the ACL for the requested share
                         write-host "These are the share permissions for the share:" -ForegroundColor red -NoNewline ; write-host "  $csharename"
                         $aclchangeshare = Get-NcCifsShareacl -Template
                         $aclchangeshare.share = "$csharename"
                         Get-NcCifsShareacl -Query $aclchangeshare | select userorgroup | format-list                          
                         
                         Write-host "What user or group do you want to remove from the SHARE ACL?" -foregroundcolor Green
                         #$grpusername = Read-Host "Enter in the user or group name in the format of domainName\userName or domainName\groupName or everyone"

                         [array]$grpusername = (Read-Host “User or Group (can specify multiple entries separated by a comma)”).split(“,”)

                         if ($grpusername -eq ""){write-host "error:Please enter in a user or group name, cannot be blank" -foregroundcolor Red}; if ($grpusername -eq $NULL) {write-host "error: Please enter in a user or group name, cannot be blank" -foregroundcolor Red}

                         Write-host
                         } while ($grpusername -eq "" -or $grpusername -eq $NULL)
     
          
                         #
                         # Requests the name of the SVM where the share is to be removed
                         #
                         DO {
                         Write-host
                         Write-host "What is the name of the Data SVM that houses the share to be removed?" -foregroundcolor Green
                         $svmname = Read-Host "Enter the name of the SVM that houses the share"

                         if ($svmname -eq ""){write-host "error:Please enter in SVM name, cannot be blank" -foregroundcolor Red}
                         
                         Write-host

                         } while ($svmname -eq "" -or $svmname -eq $NULL)     
                                                 
                         #
                         # Get the date and time for reporting a conclusion
                         #
                         $stime = get-date 

                         # Create the share and set initial permissions on the share
                         #Connect-NcController $svmip -credential $adminuser | format-table -property name,version | out-null

                         foreach ($userorgroup in $grpusername)
                          {
                          remove-nccifsshareacl -share $csharename -userorgroup $userorgroup
                          } 

                         #remove-nccifsshareacl -share $csharename -userorgroup $grpusername -vservercontext $svmname

                         write-host $stime
                         write-host "Share ACL removed from share" $csharename "on SVM" $svmname

                         Read-host "Press the ENTER key to close..."                                                   
          }
        
          modify{
          
                         #
                         # Modify ACL entry on a share
                         #  
                         DO{

                         # Obtains CIFS server name and retrieves list of shares for that CIFS server
                         write-host
                         write-host "What is the name of the CIFS server where the share resides?" -ForegroundColor Green
                         $cdotcifssvr = Read-Host "Enter the CIFS server name"

                           if ($cdotcifssvr -eq ""){write-host "error:Please enter in the CIFS server, cannot be blank" -foregroundcolor Red}

                         $aclchange = Get-NcCifsShare -Template
                         $aclchange.cifsserver = "$cdotcifssvr"
                         #Get-NcCifsShare -Query $aclchange | select sharename,acl,path | ft -AutoSize
                         Get-NcCifsShare -Query $aclchange | select sharename,path | ft -AutoSize
                         
                         Write-host
                         Write-host "What is the name of the share that you want to MODIFY an existing ACL on?" -foregroundcolor Green
                         $csharename = Read-Host "Enter the name of the share"

                         if ($csharename -eq ""){write-host "error:Please enter in the share name, cannot be blank" -foregroundcolor Red}
                         
                         Write-host

                         } while ($csharename -eq "" -or $csharename -eq $NULL)
                         
                         #
                         # This section asks for a username or group to modify the ACL entry for.
                         # It retrieves the share ACL to display to the user
                         #
                         DO{

                         # Obtains the ACL for the requested share
                         write-host "##############################################################" -ForegroundColor Green
                         write-host "These are the share permissions for the share:" -ForegroundColor red -NoNewline ; write-host "  $csharename"
                         write-host "##############################################################" -ForegroundColor Green
                         $aclchangeshare = Get-NcCifsShareacl -Template
                         $aclchangeshare.share = "$csharename"
                         Get-NcCifsShareacl -Query $aclchangeshare | select userorgroup | format-list

                         Write-host "What user or group are you modifying on the SHARE ACL?" -foregroundcolor Green
                         write-host "You must select from the ACL entries returned above!" -foregroundcolor Red
                         
                         [array]$grpusername = (Read-Host “User or Group (can specify multiple entries separated by a comma)”).split(“,”)

                         if ($grpusername -eq ""){write-host "error:Please enter in a user or group name, cannot be blank" -foregroundcolor Red}; if ($grpusername -eq $NULL) {write-host "error: Please enter in a user or group name, cannot be blank" -foregroundcolor Red}

                         Write-host
                         } while ($grpusername -eq "" -or $grpusername -eq $NULL)                         
                         
                         # 
                         # Requests the type of permissions to set on the share itself.  There are only 3 options, all will be listed in the command
                         # 
                         DO {
                         Write-host
                         Write-host "What permission do you want to set for the user or group?" -foregroundcolor Green
                         $newshareperms = Read-Host "Enter the permissions: no_access, read, change or full_control"
                          
                         if ($newshareperms -eq ""){write-host "error:Please enter in permissions, cannot be blank" -foregroundcolor Red}
                          
                         Write-host
                         } until ($newshareperms -eq "no_access" -or $newshareperms -eq "read" -or $newshareperms -eq "change" -or $newshareperms -eq "full_control")                                                  
                           
                         #
                         # Requests the name of the SVM where the share is to be modified
                         #
                         DO {
                         Write-host
                         Write-host "What is the name of the Data SVM that houses the share to be removed?" -foregroundcolor Green
                         $svmname = Read-Host "Enter the name of the SVM that houses the share"

                         if ($svmname -eq ""){write-host "error:Please enter in SVM name, cannot be blank" -foregroundcolor Red}
                         
                         Write-host

                         } while ($svmname -eq "" -or $svmname -eq $NULL)
          
                         
                         # Changes the ACL entry based on the above questions

                         foreach ($userorgroup in $grpusername)
                          {
                          set-nccifsshareacl -share $csharename -userorgroup $userorgroup -permission $newshareperms
                          } 

                         write-host $stime
                         write-host "Share ACL modifed for user or group named" $grpusername "on share" $csharename "on SVM" $svmname

                         Read-host "Press the ENTER key to close..."                     
          
          }
        
        
        }
}

##########################
# If they select option 3
# jump to here
##########################
if ($initoptions -eq 3)

{
#
#  Manage SMB Client Sessions
#
 Do { 
    
    #launching the connc function which will connect to the SVM
    Connectnc

    Write-host "STARTING CLIENT SESSION MANAGEMENT WORKFLOW" -foregroundcolor CYAN
    write-host ""
    Write-host "What do you want to do: view or close open sessions?" -foregroundcolor green
    $sessvwcls = read-host "Please enter view or close"

    Write-host 
    } until ($sessvwcls -eq "view" -or $sessvwcls -eq "close")

    #
    # Using the switch Powershell statement to keep from having nested and confusing if statements
    #

    switch ($sessvwcls)
        {
            view{
                          #
                          # Pull list of open sessions
                          #  
                          DO{

                          # Determine whether view all users or specific users
                          write-host
                          write-host "Do you want to view all sessions or check for a specific user?" -ForegroundColor Green
                          $sessallorone = Read-Host "Enter all or single"

                          if ($sessallorone -eq ""){write-host "error:Please enter in all or single, cannot be blank" -foregroundcolor Red}

                          Write-host

                          } while ($sessallorone -eq "" -or $sessallorone -eq $NULL)

                          switch ($sessallorone)
                             {
                                
                                  all{                                  
                                  $allusersess = Get-NcCifssession
                                  get-nccifssession | format-table -Property windowsuser,address,connectedtime,files,issessionsigned,node,lifaddress,protocolversion
                                     }

                                  single{
                                  write-host "Single was chosen"
                                  # Determine which user to display
                                  write-host
                                  write-host "Please enter in a single username (domain\username) or IP address of a client?" -ForegroundColor Green
                                  $sesssingle = Read-Host "Enter username or client ip address"
                                  write-host
                                  # Assumes IP first and will check for session with IP
                                  $sesssingleIP = Get-NcCifssession | where address -contains $sesssingle

                                  # Conditional check, if the output of the IP is null then it will assume username entered and pull username details
                                  # Probably a more efficient way to do this                                                                                                     
                                  if ($sesssingleIP -eq $Null)
                                  {
                                  get-nccifssession | where windowsuser -eq $sesssingle | select windowsuser,address,connectedtime,files,issessionsigned,node,lifaddress,protocolversion | format-list
                                  } 
                                  else
                                  { 
                                  Get-NcCifssession | where address -eq $sesssingle | select windowsuser,address,connectedtime,files,issessionsigned,node,lifaddress,protocolversion | format-list
                                  }
                                  
                                                                    
                                  }                                                                
                                                                   
                              }
                              
               }
        #Close start
        close{

        # Build a hash table of all the sessions and store them in a variable that will be used later to retrieve
        # the correct session for closure.  The unique key will be by Address, so if a host connects multiple times
        # from the same host, it will group them in a single entry in the has table as a Count N+     
        $sesshash = get-nccifssession | select windowsuser,address,lifaddress,node,sessionid | Group-Object -Property address -ashashtable              

        # Get the list of active sessions and display to the user just what is generally needed to close a session
        # The session is SVM-wide and not tied to a node. 
        Get-NcCifsSession | select address,windowsuser,node,sessionid | format-table -autosize
             
        # Request the session the user would like to close.  They have to use address as its the most likely to be unique                 
         Write-host
         Write-host "What session do you want to close?" -foregroundcolor Green
         $sessselect = Read-Host "Enter an IP address from the above list"                   
                 
         #Use the hash table entry for the IP address specified to close sessions
         Close-NcCifsSession -node $sesshash.item("$sessselect").node -Address $sesshash.item("$sessselect").address -SessionId $sesshash.item("$sessselect").sessionid
                           
         }
        
        #Close end
        }
}
