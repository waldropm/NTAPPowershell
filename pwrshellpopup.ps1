################################################################################
#
# This is a little script that will create a pop-up box (GUI, if you will) that
# will pass values to PowerShell cmdlets that will create a CIFS share.
#
# It will accept the inputs given, present you with a login box that is connecting
# the client to the NetApp SVM.  Then finally it will create a share based on the
# information entered into the box.  
#
# Version 1.0
# -----------
# - (4) boxes to enter in required parameters
# - Only allows for creation of a new share
# - Sets Default security for the share of Everyone / Full Control
#
################################################################################


#creates all object used throught the script

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 

$objForm = New-Object System.Windows.Forms.Form 
$objForm.Text = "Create SMB Share"
$objForm.Size = New-Object System.Drawing.Size(300,300) 
$objForm.StartPosition = "CenterScreen"

$objForm.KeyPreview = $True
$objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
    {$x=$objTextBox.Text;$objForm.Close()}})
$objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
    {$objForm.Close()}})

$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Size(75,190)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = "OK"
$OKButton.Add_Click({$x=$objTextBox.Text;$u = $objTextBox2.Text; $objForm.Close()})
$objForm.Controls.Add($OKButton)

$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Location = New-Object System.Drawing.Size(150,190)
$CancelButton.Size = New-Object System.Drawing.Size(75,23)
$CancelButton.Text = "Cancel"
$CancelButton.Add_Click({$objForm.Close()})
$objForm.Controls.Add($CancelButton)

$objLabel = New-Object System.Windows.Forms.Label
$objLabel.Location = New-Object System.Drawing.Size(10,20) 
$objLabel.Size = New-Object System.Drawing.Size(280,20) 
$objLabel.Text = "Enter name for NEW Share:"
$objForm.Controls.Add($objLabel) 

$objTextBox = New-Object System.Windows.Forms.TextBox 
$objTextBox.Location = New-Object System.Drawing.Size(10,40) 
$objTextBox.Size = New-Object System.Drawing.Size(260,20) 
$objForm.Controls.Add($objTextBox) 

$objLabel2 = New-Object System.Windows.Forms.Label
$objLabel2.Location = New-Object System.Drawing.Size(10,60) 
$objLabel2.Size = New-Object System.Drawing.Size(280,20) 
$objLabel2.Text = "Enter in the junction path:"
$objForm.Controls.Add($objLabel2) 

$objTextBox2 = New-Object System.Windows.Forms.TextBox 
$objTextBox2.Location = New-Object System.Drawing.Size(10,80) 
$objTextBox2.Size = New-Object System.Drawing.Size(260,20) 
$objForm.Controls.Add($objTextBox2) 

$objLabel3 = New-Object System.Windows.Forms.Label
$objLabel3.Location = New-Object System.Drawing.Size(10,100) 
$objLabel3.Size = New-Object System.Drawing.Size(280,20) 
$objLabel3.Text = "Enter in the SVM User Capable of making the change:"
$objForm.Controls.Add($objLabel3) 

$objTextBox3 = New-Object System.Windows.Forms.TextBox 
$objTextBox3.Location = New-Object System.Drawing.Size(10,120) 
$objTextBox3.Size = New-Object System.Drawing.Size(260,20) 
$objForm.Controls.Add($objTextBox3) 

$objLabel4 = New-Object System.Windows.Forms.Label
$objLabel4.Location = New-Object System.Drawing.Size(10,140) 
$objLabel4.Size = New-Object System.Drawing.Size(280,20) 
$objLabel4.Text = "Enter in the Data SVM that will own the share:"
$objForm.Controls.Add($objLabel4) 

$objTextBox4 = New-Object System.Windows.Forms.TextBox 
$objTextBox4.Location = New-Object System.Drawing.Size(10,160) 
$objTextBox4.Size = New-Object System.Drawing.Size(260,20) 
$objForm.Controls.Add($objTextBox4)

$objLabel5 = New-Object System.Windows.Forms.Label
$objLabel5.Location = New-Object System.Drawing.Size(10,140) 
$objLabel5.Size = New-Object System.Drawing.Size(280,20) 
$objLabel5.Text = "Enter in the Admin SVM:"
$objForm.Controls.Add($objLabel5) 

$objTextBox5 = New-Object System.Windows.Forms.TextBox 
$objTextBox5.Location = New-Object System.Drawing.Size(10,160) 
$objTextBox5.Size = New-Object System.Drawing.Size(260,20) 
$objForm.Controls.Add($objTextBox5)

$objForm.Topmost = $True

$objForm.Add_Shown({$objForm.Activate()})
[void] $objForm.ShowDialog()

# Builds the credential
$adpasswd = get-credential -credential $objtextbox3.text

# Connects to the SVM
Connect-NcController -name $objtextbox4.text -Credential $adpasswd | Out-Null

# Creates the share
add-nccifsshare -name $objtextbox.text -path $objtextbox2.text -vservercontext $objtextbox4.text
