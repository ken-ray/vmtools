# Check .NET framework version
$requiredFrameworkVersion = [Version]"4.0.30319.42000"
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
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Power VMs On/Off"
$Form.Size = New-Object System.Drawing.Size(650, 550)
$Form.MaximizeBox = $false
$Form.StartPosition = "CenterScreen"

# Create controls
$LabelHost = Create-Control -text "vCenter Host/IP:" -x 30 -y 30 -width 150 -height 20 -type "Label" -form $Form
if ($env:VCENTER_HOST) {
    $TextBoxHost         = Create-Control -text $env:VCENTER_HOST -x 180 -y 30 -width 200 -height 20 -type "TextBox" -form $Form
} else {
    $TextBoxHost = Create-Control -text "" -x 180 -y 30 -width 200 -height 20 -type "TextBox" -form $Form
}
$LabelUsername = Create-Control -text "Username:" -x 30 -y 60 -width 150 -height 20 -type "Label" -form $Form
if ($env:VCENTER_USERNAME) {
    $TextBoxUsername     = Create-Control -text $env:VCENTER_USERNAME -x 180 -y 60 -width 200 -height 20 -type "TextBox" -form $Form
} else {
    $TextBoxUsername = Create-Control -text "" -x 180 -y 60 -width 200 -height 20 -type "TextBox" -form $Form
}
$LabelPassword = Create-Control -text "Password:" -x 30 -y 90 -width 150 -height 20 -type "Label" -form $Form
$TextBoxPassword = Create-Control -text '' -x 180 -y 90 -width 200 -height 20 -type "TextBox" -form $Form
$TextBoxPassword.PasswordChar = "*"
$ButtonConnect = Create-Control -text "Connect" -x 180 -y 130 -width 100 -height 30 -type "Button" -form $Form
$StatusLabel = Create-Control -text "" -x 180 -y 175 -width 360 -height 20 -type "Label" -form $Form
$LabelFolder = Create-Control -text "Select VM Folder:" -x 30 -y 210 -width 150 -height 20 -type "Label" -form $Form
$ComboBoxFolder = Create-Control -x 180 -y 210 -width 200 -height 20 -type "ComboBox" -form $Form
$ListBoxVMs = Create-Control -x 180 -y 250 -width 300 -height 150 -type "ListBox" -form $Form
$ListBoxVMs.SelectionMode = "MultiExtended"
$ButtonPowerOn = Create-Control -text "Power On" -x 180 -y 410 -width 100 -height 30 -type "Button" -form $Form
$ButtonPowerOff = Create-Control -text "Power Off" -x 300 -y 410 -width 100 -height 30 -type "Button" -form $Form

# Function to publish VM folder dropdown
function Publish-VMFolderDropdown {
    param (
        $folder,
        $comboBox
    )

    $comboBox.Items.Clear()
    $comboBox.DisplayMember = "Name"
    $comboBox.ValueMember = "Id"

    foreach ($f in $folder) {
        $null = $comboBox.Items.Add($f)
    }

    $comboBox.SelectedIndex = -1
}

# Function to connect to vCenter
function Connect-TovCenter {
    param (
        [string]$vHost,
        [string]$username,
        [string]$pword
    )

    try {
        $null = Connect-VIServer -Server $vHost -Username $username -Password $pword -ErrorAction Stop
        return $true
    }
    catch {
        Write-Host "Failed to connect to vCenter: $_" -ForegroundColor Red
        return $false
    }
}

# Event handler for Connect button
$ButtonConnect.Add_Click({
    $vcHost = $TextBoxHost.Text.Trim()
    $vCenterUsername = $TextBoxUsername.Text.Trim()
    $vCenterPassword = $TextBoxPassword.Text.Trim()

    if ($vcHost -eq "" -or $vCenterUsername -eq "" -or $vCenterPassword -eq "") {
        $StatusLabel.Text = "Please enter vCenter credentials."
        $StatusLabel.ForeColor = "Red"
        $ListBoxVMs.Enabled = $false
        $ButtonPowerOn.Enabled = $false
        $ButtonPowerOff.Enabled = $false
    }
    else {
        $connected = Connect-TovCenter -vHost $vcHost -username $vCenterUsername -pword $vCenterPassword

        if ($connected) {
            $StatusLabel.Text = "Connected to vCenter."
            $StatusLabel.ForeColor = "Green"
            $ButtonConnect.Enabled = $false
            $ListBoxVMs.Enabled = $true
            $ButtonPowerOn.Enabled = $true
            $ButtonPowerOff.Enabled = $true

            # Publish the VM folder dropdown
            $rootFolder = Get-Folder -Type VM | Sort-Object Name
            Publish-VMFolderDropdown -folder $rootFolder -comboBox $ComboBoxFolder
        }
        else {
            $StatusLabel.Text = "Failed to connect to vCenter."
            $StatusLabel.ForeColor = "Red"
            $ListBoxVMs.Enabled = $false
            $ButtonPowerOn.Enabled = $false
            $ButtonPowerOff.Enabled = $false
        }
    }
})

# Event handler for VM folder selection
$ComboBoxFolder.Add_SelectedIndexChanged({
    $selectedFolder = $ComboBoxFolder.SelectedItem

    if ($selectedFolder) {
        $vms = $selectedFolder | Get-VM | Sort-Object Name
        $ListBoxVMs.Items.Clear()
        if ($vms.Count -lt 1) {
        }
        elseif ($vms.Count -lt 2) {
            $ListBoxVMs.Items.Add($vms) }
        else {
        $ListBoxVMs.Items.AddRange($vms) }
    }
})

# Event handler for Power On button
$ButtonPowerOn.Add_Click({
    $selectedVMs = $ListBoxVMs.SelectedItems

    if ($selectedVMs.Count -eq 0) {
        $StatusLabel.Text = "Please select VM(s) to power on."
        $StatusLabel.ForeColor = "Red"
    }
    else {
        Write-Host "`nPowering on VMs..."
        $selectedVMs | ForEach-Object {
            $vm = $_
            try {
                Start-VM -VM $vm -Confirm:$false -RunAsync
                Write-Host "Powered on VM: $vm"
            }
            catch {
                Write-Host "Failed to power on VM: $_" -ForegroundColor Red
            }
        }

        $StatusLabel.Text = "VM(s) powered on successfully."
        $StatusLabel.ForeColor = "Green"
    }
})

# Event handler for Power Off button
$ButtonPowerOff.Add_Click({
    $selectedVMs = $ListBoxVMs.SelectedItems

    if ($selectedVMs.Count -eq 0) {
        $StatusLabel.Text = "Please select VM(s) to power off."
        $StatusLabel.ForeColor = "Red"
    }
    else {
        Write-Host "`nPowering off VMs..."
        $selectedVMs | ForEach-Object {
            $vm = $_
            try {
                $null = Stop-VM -VM $vm -Confirm:$false -RunAsync
                Write-Host "Powered off VM: $vm"
            }
            catch {
                Write-Host "Failed to power off VM: $_" -ForegroundColor Red
            }
        }

        $StatusLabel.Text = "VM(s) powered off successfully."
        $StatusLabel.ForeColor = "Green"
    }
})

# Show the form
$null = $Form.ShowDialog()
