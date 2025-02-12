# Check .NET framework version
$requiredFrameworkVersion  = [Version]"4.0.30319.42000"
$installedFrameworkVersion = [System.Environment]::Version

if ($installedFrameworkVersion -lt $requiredFrameworkVersion) {
    Write-Host -ForegroundColor Red "Required .NET framework version $requiredFrameworkVersion or later is not installed. You are running $installedFrameworkVersion"
    Exit 1
}

# Check prerequisites
$prerequisites = @(
    "VMware.PowerCLI"
)

$missingModules = $prerequisites | Where-Object { -not (Get-Module $_ -ListAvailable) }

if ($missingModules) {
    $missingModules -join ", " | Write-Host -ForegroundColor Red
    Write-Host "Please install the missing modules listed above before running this script."
    Exit 1
}

Add-Type -AssemblyName System.Windows.Forms

# Function to create controls
function Create-Control {
    param(
        [string]$text,
        [int]$x,
        [int]$y,
        [int]$width,
        [int]$height,
        [string]$type,
        [System.Windows.Forms.Form]$form
    )

    $control = New-Object System.Windows.Forms.$type
    $control.Text = $text
    $control.Location = New-Object System.Drawing.Point($x, $y)
    $control.Size = New-Object System.Drawing.Size($width, $height)
    $form.Controls.Add($control)

    return $control
}

# Create a form
$Form      = New-Object System.Windows.Forms.Form
$Form.Text = "Register VMs"
$Form.Size = New-Object System.Drawing.Size(650, 500)
$Form.MaximizeBox = $false
$Form.StartPosition = "CenterScreen"

# Create controls
$LabelHost           = Create-Control -text "vCenter Host/IP:" -x 30 -y 30 -width 150 -height 20 -type "Label" -form $Form
if ($env:VCENTER_HOST) {
    $TextBoxHost         = Create-Control -text $env:VCENTER_HOST -x 180 -y 30 -width 200 -height 20 -type "TextBox" -form $Form
} else {
    $TextBoxHost         = Create-Control -text "" -x 180 -y 30 -width 200 -height 20 -type "TextBox" -form $Form
}
$LabelUsername       = Create-Control -text "Username:" -x 30 -y 60 -width 150 -height 20 -type "Label" -form $Form
if ($env:VCENTER_USERNAME) {
    $TextBoxUsername     = Create-Control -text $env:VCENTER_USERNAME -x 180 -y 60 -width 200 -height 20 -type "TextBox" -form $Form
} else {
    $TextBoxUsername     = Create-Control -text "" -x 180 -y 60 -width 200 -height 20 -type "TextBox" -form $Form
}
$LabelPassword       = Create-Control -text "Password:" -x 30 -y 90 -width 150 -height 20 -type "Label" -form $Form
$TextBoxPassword     = Create-Control -text '' -x 180 -y 90 -width 200 -height 20 -type "TextBox" -form $Form
$TextBoxPassword.PasswordChar = "*"
$ButtonConnect       = Create-Control -text "Connect" -x 180 -y 130 -width 100 -height 30 -type "Button" -form $Form
$StatusLabel         = Create-Control -text "" -x 180 -y 175 -width 360 -height 20 -type "Label" -form $Form
$LabelDatastore      = Create-Control -text "Select Datastore:" -x 30 -y 210 -width 150 -height 20 -type "Label" -form $Form
$ComboBoxDatastore   = Create-Control -x 180 -y 210 -width 200 -height 20 -type "ComboBox" -form $Form
$ButtonScanDatastore = Create-Control -text "Scan Datastore" -x 400 -y 210 -width 120 -height 20 -type "Button" -form $Form
$ListBoxVMs          = Create-Control -x 180 -y 250 -width 400 -height 100 -type "ListBox" -form $Form
$ButtonRegisterVMs   = Create-Control -text "Register VMs" -x 180 -y 360 -width 120 -height 30 -type "Button" -form $Form

# Handler for the Connect button click
$ButtonConnect.Add_Click({
    $vCenterHost      = $TextBoxHost.Text
    $vCenterUsername  = $TextBoxUsername.Text
    $vCenterPassword  = $TextBoxPassword.Text
    $env:VCENTER_HOST = $TextBoxHost.Text
    $env:VCENTER_USERNAME =$TextBoxUsername.Text

    # Connect to vCenter server
    try {
        Connect-VIServer -Server $vCenterHost -Username $vCenterUsername -Password $vCenterPassword -ErrorAction Stop

        # Connection successful
        $StatusLabel.Text = "Connected to vCenter!"
        $StatusLabel.ForeColor = [System.Drawing.Color]::Green
        $ButtonConnect.Enabled = $false

        # Get the list of datastores
        $datastores = Get-Datastore | Sort-Object Name | Where-Object { $_.Type -eq "VMFS" -or $_.Type -eq "NFS" } | Select-Object -ExpandProperty Name


        # Populate the combobox with the datastores
        $ComboBoxDatastore.Items.Clear()
        $ComboBoxDatastore.Items.AddRange($datastores)
    }
    catch {
        # Connection failed
        $StatusLabel.Text = "Connection failed!"
        $StatusLabel.ForeColor = [System.Drawing.Color]::Red
    }
})

# Handler for the ComboBox Selection Change
$comboBoxDatastore.add_SelectedIndexChanged({
    # Clear the ListBox when the selection changes in the ComboBox
    $ListBoxVMs.Items.Clear()
})

# Handler for the Scan Datastore button click
$ButtonScanDatastore.Add_Click({
  if ($ComboBoxDatastore.SelectedItem) {
    $ButtonScanDatastore.Enabled = $false
    $ListBoxVMs.Items.Clear()
    Start-Sleep -Milliseconds 500
    $StatusLabel.Text = "Scanning the Datastore. This can take a while."
    $StatusLabel.ForeColor = [System.Drawing.Color]::Green
    Start-Sleep -Milliseconds 5

    $selectedDatastore = $ComboBoxDatastore.SelectedItem.ToString()
    $script:DS = Get-Datastore -Name $selectedDatastore

    # Scan the selected datastore for VMX files
    New-PSDrive -Name TmpTgtDS -Location $DS -PSProvider VimDatastore -Root '\'
    #$vmxFiles = Get-ChildItem -Path TmpTgtDS: -Filter "*.vmx" -Recurse | Select-Object -ExpandProperty Name
    $vmxFiles = Get-ChildItem -Path TmpTgtDS: -Filter "*.vmx" -Recurse | ForEach-Object { [PSCustomObject]@{
        Name = $_.Name
        FullName = $_.FullName -replace '^.*\\\\'}
    } | Sort-Object Name
    Remove-PSDrive -Name TmpTgtDS

    $StatusLabel.Text = "Scan Complete. Verifying UnRegistered VMs."
    $StatusLabel.ForeColor = [System.Drawing.Color]::Green
    Start-Sleep -Milliseconds 5

    # Check if VMX files are registered virtual machines
    $vm = Get-VM | Select-Object -Property @{Name = 'VMFilename'; Expression = { $_.ExtensionData.Config.Files.VmPathName.Split("/")[-1] }}, @{Name = 'Datastore'; Expression = { $_.ExtensionData.Config.DatastoreUrl.Name }} -ErrorAction SilentlyContinue 
    $unregisteredVMObjects = foreach ($vmxFile in $vmxFiles) {
       $isMatch = $false
       foreach ($v in $vm) {
           if ($vmxFile.Name -eq $v.VMFilename) {
              if ($DS.ToString() -ceq $v.Datastore.ToString()) {
                 $isMatch = $true
                 break
              }
           }
       }
       if (-not $isMatch) {
           # Create a custom object with Name and Fullname properties
           [PSCustomObject]@{
               Name = $vmxFile.Name
               Fullname = $vmxFile.FullName
           }
       }
   }

    # Update the list box with the unregistered VMX files
    $ListBoxVMs.Items.Clear()

    if ($unregisteredVMObjects) {
       if ($unregisteredVMObjects.Count -lt 2) {
          $ListBoxVMs.Items.Add($unregisteredVMObjects)
          $ListBoxVMs.DisplayMember = 'Name'
          $ListBoxVMs.ValueMember   = 'Fullname'
       }
       else { 
          $ListBoxVMs.Items.AddRange($unregisteredVMObjects)
          $ListBoxVMs.DisplayMember = 'Name'
          $ListBoxVMs.ValueMember   = 'Fullname'
       }
    }

    # Enable multi-select in ListBox
    $ListBoxVMs.SelectionMode = [System.Windows.Forms.SelectionMode]::MultiExtended

    $StatusLabel.Text = "UnRegistered VMs Listed."
    $StatusLabel.ForeColor = [System.Drawing.Color]::Green
    $ButtonScanDatastore.Enabled = $true
  }
  else {
    [System.Windows.Forms.MessageBox]::Show("Please select a Datastore to scan.", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
  }
})

$ButtonRegisterVMs.Add_Click({
    if (-not $ListBoxVMs.SelectedItems) {
        # No VMs selected
        [System.Windows.Forms.MessageBox]::Show("Please select VMs to register.", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    else {
        # Open the new window for selecting VM folder and resource pool
        & {
            Add-Type -AssemblyName System.Windows.Forms
            Add-Type -AssemblyName System.Drawing

            # Create a new form
            $form = New-Object System.Windows.Forms.Form
            $form.Text = "Register VMs"
            $form.Size = New-Object System.Drawing.Size(420, 500)
            $form.StartPosition = "CenterScreen"
            $form.FormBorderStyle = "FixedDialog"
            $form.MaximizeBox = $false

            # Create a label for the VMs list
            $labelVMs = New-Object System.Windows.Forms.Label
            $labelVMs.Text = "Selected VMs:"
            $labelVMs.AutoSize = $true
            $labelVMs.Location = New-Object System.Drawing.Point(10, 10)
            $form.Controls.Add($labelVMs)

            # Create a list box to display the selected VMs
            $listBoxVMs2 = New-Object System.Windows.Forms.ListBox
            $listBoxVMs2.Location = New-Object System.Drawing.Point(10, 30)
            $listBoxVMs2.Size = New-Object System.Drawing.Size(380, 150)
            $listBoxVMs2.SelectionMode = "MultiExtended"
            $form.Controls.Add($listBoxVMs2)

            # Populate the list box with selected VMs from the original ListBox
            $selectedItems = $ListBoxVMs.SelectedItems
            foreach ($item in $selectedItems) {
                $listBoxVMs2.Items.Add($item.Fullname)
            }

            for ($i = 0; $i -lt $listBoxVMs2.Items.Count; $i++) {
                $listBoxVMs2.SetSelected($i, $true)
            }

            # Create a label for the VM folder dropdown box
            $labelFolder = New-Object System.Windows.Forms.Label
            $labelFolder.Text = "Select VM Folder:"
            $labelFolder.AutoSize = $true
            $labelFolder.Location = New-Object System.Drawing.Point(10, 190)
            $form.Controls.Add($labelFolder)

            # Create a dropdown box for selecting the VM folder
            $comboBoxFolder = New-Object System.Windows.Forms.ComboBox
            $comboBoxFolder.Location = New-Object System.Drawing.Point(10, 210)
            $comboBoxFolder.Size = New-Object System.Drawing.Size(380, 25)

            # Get the VM folders from vCenter and populate the dropdown box
            $vmFolders = Get-Folder -Type VM | Sort-Object Name | Select-Object -ExpandProperty Name
            $comboBoxFolder.Items.AddRange($vmFolders)

            $form.Controls.Add($comboBoxFolder)

            # Create a label for the resource pool dropdown box
            $labelPool = New-Object System.Windows.Forms.Label
            $labelPool.Text = "Select Resource:"
            $labelPool.AutoSize = $true
            $labelPool.Location = New-Object System.Drawing.Point(10, 250)
            $form.Controls.Add($labelPool)

            # Create a dropdown box for selecting the resource pool
            $comboBoxPool = New-Object System.Windows.Forms.ComboBox
            $comboBoxPool.Location = New-Object System.Drawing.Point(10, 270)
            $comboBoxPool.Size = New-Object System.Drawing.Size(380, 25)

            # Get the resource pools from vCenter and populate the dropdown box
            $cluster       = Get-Cluster | Sort-Object Name | Select-Object -ExpandProperty Name
            $resourcePools = Get-ResourcePool | Sort-Object Name | Select-Object -ExpandProperty Name
            $vmhosts       = Get-VMhost | Sort-Object Name | Select-Object -ExpandProperty Name

            $comboBoxPool.Items.AddRange($cluster)
            $comboBoxPool.Items.AddRange($resourcePools)
            $comboBoxPool.Items.AddRange($vmhosts)

            $form.Controls.Add($comboBoxPool)

            # Create a label for the suffix radio buttons
            $labelRadio = New-Object System.Windows.Forms.Label
            $labelRadio.Text = "Would you like to add a suffix to the VM Name:"
            $labelRadio.AutoSize = $true
            $labelRadio.Location = New-Object System.Drawing.Point(10, 310)
            $form.Controls.Add($labelRadio)

            # Create a radio button for adding a suffix to VM name
            $radioButtonYes = New-Object System.Windows.Forms.RadioButton
            $radioButtonYes.Location = New-Object System.Drawing.Point(10, 330)
            $radioButtonYes.Size = New-Object System.Drawing.Size(50, 20)
            $radioButtonYes.Text = "Yes"
            $form.Controls.Add($radioButtonYes)

            # Create a radio button for not adding a suffix to VM name
            $radioButtonNo = New-Object System.Windows.Forms.RadioButton
            $radioButtonNo.Location = New-Object System.Drawing.Point(70, 330)
            $radioButtonNo.Size = New-Object System.Drawing.Size(50, 20)
            $radioButtonNo.Text = "No"
            $radioButtonNo.Checked = $true
            $form.Controls.Add($radioButtonNo)

            # Create a label for the suffix text box
            $labelSuffix = New-Object System.Windows.Forms.Label
            $labelSuffix.Text = "VM Name Suffix:"
            $labelSuffix.AutoSize = $true
            $labelSuffix.Location = New-Object System.Drawing.Point(10, 360)
            $form.Controls.Add($labelSuffix)

            # Create a text box for entering the suffix
            $textBoxSuffix = New-Object System.Windows.Forms.TextBox
            $textBoxSuffix.Location = New-Object System.Drawing.Point(10, 380)
            $textBoxSuffix.Size = New-Object System.Drawing.Size(380, 25)
            $textBoxSuffix.Enabled = $false
            $form.Controls.Add($textBoxSuffix)

            # Add event handler for radio button click event
            $radioButtonYes.Add_Click({
                $textBoxSuffix.Enabled = $true
            })

            $radioButtonNo.Add_Click({
                $textBoxSuffix.Enabled = $false
            })

            # Create a button for registering the VMs
            $buttonRegister = New-Object System.Windows.Forms.Button
            $buttonRegister.Location = New-Object System.Drawing.Point(150, 420)
            $buttonRegister.Size = New-Object System.Drawing.Size(100, 30)
            $buttonRegister.Text = "Register VMs"

$buttonRegister.Add_Click({
    $selectedVMs = $listBoxVMs2.SelectedItems
    $selectedFolder = $comboBoxFolder.SelectedItem
    $selectedPool = $comboBoxPool.SelectedItem
    $ListBoxVMs.Items.Clear()
    Start-Sleep -Milliseconds 5

    if ($radioButtonYes.Checked) {
        $ToSuffixorNot = $true
        $SuffixName = $textBoxSuffix.Text
    } else {
        $ToSuffixorNot = $false
    }
    if ($selectedVMs) {
        if ($selectedFolder) {
            if ($selectedPool) {
                $resultsForm = New-Object System.Windows.Forms.Form
                $resultsForm.Text = "VM Registration Results"
                $resultsForm.Size = New-Object System.Drawing.Size(400, 400)
                $resultsForm.StartPosition = "CenterScreen"

                $resultsLabel = New-Object System.Windows.Forms.Label
                $resultsLabel.Text = "Registration Status:"
                $resultsLabel.AutoSize = $true
                $resultsLabel.Location = New-Object System.Drawing.Point(10, 10)
                $resultsForm.Controls.Add($resultsLabel)
                $cntr = 1

                foreach ($vm in $selectedVMs) {
                    $newVMName = $vm.Split('\')[-1] -replace ".vmx"
                    $vmxFile = "[$DS] /$vm"
                    if ($ToSuffixorNot){
                      $newVMName = $newVMName + $SuffixName
                    }
                    $statusLabel = New-Object System.Windows.Forms.Label
                    $statusLabel.Text = "Registering VMs..."
                    $statusLabel.AutoSize = $true
                    $statusLabel.Location = New-Object System.Drawing.Point(10, ($resultsLabel.Bottom + 20))
                    $resultsForm.Controls.Add($statusLabel)

                    # Register the VM
                    $registerResult = New-VM -RunAsync -Name $newVMName -VMFilePath $vmxFile -Location $selectedFolder -ResourcePool $selectedPool -ErrorVariable registrationError -ErrorAction SilentlyContinue 
                    # Display the registration status
                    $status = "Failed!"
                    if ($registrationError) {
                        $errorMessage = $registrationError[0].Exception.Message
                        if ($errorMessage -match "already exists") {
                           $status = "Failed! VM Name Already Exists!"
                        }
                    }
                    if ($registerResult) {
                        $status = "Success"
                    }

                    $statusResultLabel = New-Object System.Windows.Forms.Label
                    $statusResultLabel.Text = "VM   '$newVMName' `t`t  registration status: $status"
                    if ($status -eq "Success") {
                       $StatusResultLabel.ForeColor = "Green" }
                    else {
                       $statusResultLabel.Forecolor = "Red" }
                    $statusResultLabel.AutoSize = $true
                    $statusResultLabel.Location = New-Object System.Drawing.Point(30, ($statusLabel.Bottom + (10 * $cntr)))
                    $resultsForm.Controls.Add($statusResultLabel)
                    $cntr += 2
                }

                $null = $resultsForm.ShowDialog()
                $resultsForm.Dispose()
                $form.Close()
            }
            else {
                [System.Windows.Forms.MessageBox]::Show("Please select a Resource.", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            }
        }
        else {
            [System.Windows.Forms.MessageBox]::Show("Please select a VM Folder.", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    }
    else {
        # No VMs selected
        [System.Windows.Forms.MessageBox]::Show("Please select VMs to register.", "Information", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
})
$form.Controls.Add($buttonRegister)

# Show the form
$null = $form.ShowDialog()
    }
}
})

# Show the form
$null = $Form.ShowDialog()

# Event handler for the FormClosing event
$Form.add_FormClosing({
    # Clean up resources
    $Form.Dispose
    Disconnect-VIServer -Server $TextBoxHost.Text -Confirm:$false
})