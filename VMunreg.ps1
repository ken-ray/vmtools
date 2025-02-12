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
$Form.Text = "Unregister VMs"
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
$LabelFolder         = Create-Control -text "Select VM Folder:" -x 30 -y 210 -width 150 -height 20 -type "Label" -form $Form
$ComboBoxFolder      = Create-Control -x 180 -y 210 -width 200 -height 20 -type "ComboBox" -form $Form
$ListBoxVMs          = Create-Control -x 180 -y 250 -width 300 -height 150 -type "ListBox" -form $Form
$ListBoxVMs.SelectionMode = "MultiExtended"
$ButtonUnregisterVMs = Create-Control -text "Unregister VMs" -x 180 -y 410 -width 100 -height 30 -type "Button" -form $Form

# Function to publish VM folder dropdown
function Publish-VMFolderDropdown {
    param (
        $folder,
        $comboBox
    )

    $comboBox.Items.Clear()
    $comboBox.DisplayMember = "Name"
    $comboBox.ValueMember   = "Id"

    foreach ($f in $folder) {
            $null = $comboBox.Items.Add($f) 
        }

    $comboBox.SelectedIndex = -1
}

# Function to publish VM listbox
function Publish-VMListbox {
    param (
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.FolderImpl]$folder,
        [System.Windows.Forms.ListBox]$listBox
    )

    $listBox.Items.Clear()

    $folder | Get-VM | Sort-Object Name | ForEach-Object {
        $null = $listBox.Items.Add($_.Name)
    }
}

# Function to connect to vCenter
function Connect-TovCenter {
    param (
        [string]$vHost,
        [string]$username,
        [string]$pword
    )

    try {
        $null = Connect-VIServer -Server $vcHost -Username $username -Password $pword -ErrorAction Stop
        return $true
    }
    catch {
        Write-Host "Failed to connect to vCenter: $_" -ForegroundColor Red
        return $false
    }
}

# Event handler for Connect button
$ButtonConnect.Add_Click({
    $vcHost          = $TextBoxHost.Text.Trim()
    $vCenterUsername = $TextBoxUsername.Text.Trim()
    $vCenterPassword = $TextBoxPassword.Text.Trim()

    if ($vcHost -eq "" -or $vCenterUsername -eq "" -or $vCenterPassword -eq "") {
        $StatusLabel.Text        = "Please enter vCenter credentials."
        $StatusLabel.ForeColor   = "Red"
        $ListBoxVMs.Enabled      = $false
        $ButtonUnregisterVMs.Enabled = $false
    }
    else {
        $connected = Connect-TovCenter -host $vHost -username $vCenterUsername -pword $vCenterPassword

        if ($connected) {
            $StatusLabel.Text      = "Connected to vCenter."
            $StatusLabel.ForeColor = "Green"
            $ButtonConnect.Enabled = $false
            $ListBoxVMs.Enabled    = $true
            $ButtonUnregisterVMs.Enabled = $true

            # Publish the VM folder dropdown
            $rootFolder = Get-Folder -Type VM | Sort-Object Name
            Publish-VMFolderDropdown -folder $rootFolder -comboBox $ComboBoxFolder
        }
        else {
            $StatusLabel.Text        = "Failed to connect to vCenter."
            $StatusLabel.ForeColor   = "Red"
            $ListBoxVMs.Enabled      = $false
            $ButtonUnregisterVMs.Enabled = $false
        }
    }
})

# Event handler for VM folder selection
$ComboBoxFolder.Add_SelectedIndexChanged({
    $selectedFolder = $ComboBoxFolder.SelectedItem

    if ($selectedFolder) {
        Publish-VMListbox -folder $selectedFolder -listBox $ListBoxVMs
    }
})

# Event handler for Unregister button
$ButtonUnregisterVMs.Add_Click({
    $selectedVMs = $ListBoxVMs.SelectedItems

    if ($selectedVMs.Count -eq 0) {
        $StatusLabel.Text      = "Please select VM(s) to unregister."
        $StatusLabel.ForeColor = "Red"
    }
    else {
        Write-Host "`nUnregistering VMs..."
        $selectedVMs | ForEach-Object {
            try {
                $vm = Get-VM -Name $_ | Sort-Object Name
                if ($vm.PowerState -eq 'PoweredOn') {
                    Write-Host "$vm is powered on and cannot be unregistered."
                }
                else {
                    $null = Remove-VM -VM $vm -RunAsync -Confirm:$false
                    Write-Host "Unregistered VM: $vm"
                }
            }
            catch {
                Write-Host "Failed to unregister VM: $_" -ForegroundColor Red
            }
        }
        Start-Sleep -Milliseconds 500
        $StatusLabel.Text      = "Review VM unregistration output."
        $StatusLabel.ForeColor = "Green"

        # Refresh the VM listbox
        $selectedFolder = $ComboBoxFolder.SelectedItem

        if ($selectedFolder) {
            Publish-VMListbox -folder $selectedFolder -listBox $ListBoxVMs
        }
    }
})

# Show the form
$null = $Form.ShowDialog()