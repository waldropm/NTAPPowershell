# ################################################################################################
# ################################################################################################
# Script name - sharebackup.ps1
#
# -----------
# -----------
# --Details--
# -----------
#
# This is a simple script that backs up to a file the basic details on the configuration of CIFS
# shares in a clustered Data ONTAP Environment (8.3 and later.  The script will create (2) output 
# files that will be stored on a path that you define ($filestorepath).
#
# Verion 1.0
# ----------
# 06/09/2015
#
# - includes basic backup of sharename  and ACLs
# - does not backup information about any hidden shares ($)...see code comments for more details
# ################################################################################################
# ################################################################################################

# Makes sure that the parameters necessary to run the script have been provided
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
# This does use a customer PowerShell module that retrieves a stored Credential that you create in
# the Windows Credential Manager.  See posts on http://threewhistles.wordpress.com for more details
# on this module including where to get it and installing.
#
# Please consult your own internal security requirements before using the script in production
# to ensure it meets your environments internal security requirements.
Set-ExecutionPolicy bypass
$svmcredstore = get-storedcredential $wincredstor

#
# Function created to call when connect to the SVM is necessary
# Easier than extra coding of the connect-nccontroller cmdlet
# 
# Building this now in the event the script expands to an backup and import
# or other actions against cifs shares
#
function Connectnc
{
Connect-NcController $svmmgtlif -Credential $svmcredstore | format-table -property name,version | out-null
}

# Reusable variables
$filestorepath = "c:\data\scripts\blog_articles"

# Removes any existing file.  Later work could be done to check for the existance of this file
# make a copy and then remove the old one for historical reference or compliance reasons    
Remove-Item -Path "$filestorepath\shareout_$svmmgtlif.csv" -ErrorAction SilentlyContinue
Remove-Item -Path "$filestorepath\shareaclout_$svmmgtlif.csv"-ErrorAction SilentlyContinue

# Connect to the SVM using the defined function
connectnc

# Grab a list of shares, the path in cDOT (ie: Junction path) and shareproperties
# and store it in a file.  You can change the path to whatever works for you.
#
# If you desire the ability to backup all shares, hidden (defined with appending $) and all, then
# you will want to remove the line referencing where {$_.sharename.contains("$")
get-nccifsshare | select sharename,path,@{name="shareproperties";expression={[string]::Join(",",($_.shareproperties)) -replace '[{}]',''}}`
 | where {$_.ShareName.contains("$") -ne "false"} `
 |ConvertTo-Csv -Delimiter ";" -OutVariable shareback -NoTypeInformation | out-null
$shareback[1..($shareback.count – 1)] `
| ForEach-Object {Add-Content -Value $_ -Path "$filestorepath\shareout_$svmmgtlif.csv"}


# Get a list of the shares, retrieve the ACLS and output it to a path
get-nccifsshareacl | select share,userorgroup,permission | where {$_.Share.contains("$") -ne "false"} `
 |ConvertTo-Csv -OutVariable shareaclback -NoTypeInformation | out-null
$shareaclback[1..($shareaclback.count – 1)] `
| ForEach-Object {Add-Content -Value $_ -Path "$filestorepath\shareaclout_$svmmgtlif.csv"}
