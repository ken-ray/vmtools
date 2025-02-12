Add-Type -AssemblyName System.Windows.Forms

# Create a new form
$form = New-Object System.Windows.Forms.Form
$form.Text = "VM Tools"
$form.Size = New-Object System.Drawing.Size(400, 225)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.StartPosition = "CenterScreen"

# Create the Register button
$buttonRegister = New-Object System.Windows.Forms.Button
$buttonRegister.Text = "Register VMs"
$buttonRegister.Size = New-Object System.Drawing.Size(150, 50)
$buttonRegister.Location = New-Object System.Drawing.Point(20, 30)
$buttonRegister.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
$buttonRegister.Add_Click({
    #Start-Process -FilePath "powershell.exe" -ArgumentList "-File", "vmreg.ps1" -WindowStyle Hidden
    & "$PSScriptRoot/vmreg.ps1"
})
$buttonRegister.TabStop = $false
$form.Controls.Add($buttonRegister)

# Create the Net Connect button
$buttonNetConnect = New-Object System.Windows.Forms.Button
$buttonNetConnect.Text = "Connect VM Networks"
$buttonNetConnect.Size = New-Object System.Drawing.Size(150, 50)
$buttonNetConnect.Location = New-Object System.Drawing.Point(210, 30)
$buttonNetConnect.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
$buttonNetConnect.Add_Click({
    & "$PSScriptRoot/vmnetconnect.ps1"
})
$buttonNetConnect.TabStop = $false
$form.Controls.Add($buttonNetConnect)

# Create the Unregister button
$buttonPowerVM = New-Object System.Windows.Forms.Button
$buttonPowerVM.Text = "Power VMs On/Off"
$buttonPowerVM.Size = New-Object System.Drawing.Size(150, 50)
$buttonPowerVM.Location = New-Object System.Drawing.Point(20, 100)
$buttonPowerVM.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
$buttonPowerVM.Add_Click({
    & "$PSScriptRoot/vmpower.ps1"
})
$buttonPowerVM.TabStop = $false
$form.Controls.Add($buttonPowerVM)

# Create the Unregister button
$buttonUnregister = New-Object System.Windows.Forms.Button
$buttonUnregister.Text = "Unregister VMs"
$buttonUnregister.Size = New-Object System.Drawing.Size(150, 50)
$buttonUnregister.Location = New-Object System.Drawing.Point(210, 100)
$buttonUnregister.Font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
$buttonUnregister.Add_Click({
    #Start-Process -FilePath "powershell.exe" -ArgumentList "-File", "vmunreg.ps1"
    & "$PSScriptRoot/vmunreg.ps1"
})
$buttonUnRegister.TabStop = $false
$form.Controls.Add($buttonUnregister)

# Show the form
[void]$form.ShowDialog()