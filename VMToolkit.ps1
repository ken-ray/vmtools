Add-Type -AssemblyName PresentationFramework

$XAML = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="VM Toolkit" Height="400" Width="600" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <Window.Resources>
        <!-- Header gradient background -->
        <LinearGradientBrush x:Key="HeaderBackground" StartPoint="0,0" EndPoint="1,0">
            <GradientStop Color="#007ACC" Offset="0.0" />
            <GradientStop Color="#005A9E" Offset="1.0" />
        </LinearGradientBrush>
        <!-- Modern button style -->
        <Style x:Key="ModernButton" TargetType="Button">
            <Setter Property="FontFamily" Value="Segoe UI"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Margin" Value="5"/>
            <Setter Property="Padding" Value="5"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Background" Value="#007ACC"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Width" Value="140"/>
            <Setter Property="Height" Value="40"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="4">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid Background="#FFF5F5F5">
        <Grid.RowDefinitions>
            <RowDefinition Height="120"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        <!-- Header Section -->
        <Border Grid.Row="0" Background="{StaticResource HeaderBackground}">
            <DockPanel>
                <TextBlock Text="VM Toolkit" Foreground="White" FontFamily="Segoe UI" FontSize="28"
                           VerticalAlignment="Center" HorizontalAlignment="Center" Margin="10"/>
            </DockPanel>
        </Border>
        <!-- Content Area with Buttons -->
        <UniformGrid Grid.Row="1" Rows="2" Columns="2" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="10">
            <Button Name="RegisterButton" Content="Register VMs" Style="{StaticResource ModernButton}"/>
            <Button Name="ConnectButton" Content="Connect VM Networks" Style="{StaticResource ModernButton}"/>
            <Button Name="PowerButton" Content="Power VMs On/Off" Style="{StaticResource ModernButton}"/>
            <Button Name="UnregisterButton" Content="Unregister VMs" Style="{StaticResource ModernButton}"/>
        </UniformGrid>
    </Grid>
</Window>
'@

try {
    $Window = [Windows.Markup.XamlReader]::Parse($XAML)
} catch {
    Write-Error "Failed to load XAML: $_"
    exit
}

$RegisterButton   = $Window.FindName("RegisterButton")
$ConnectButton    = $Window.FindName("ConnectButton")
$PowerButton      = $Window.FindName("PowerButton")
$UnregisterButton = $Window.FindName("UnregisterButton")


$RegisterButton.Add_Click({
    & "$PSScriptRoot/vmreg.ps1"
})
$ConnectButton.Add_Click({
    & "$PSScriptRoot/vmnetconnect.ps1"
})
$PowerButton.Add_Click({
    & "$PSScriptRoot/vmpower.ps1"
})
$UnregisterButton.Add_Click({
    & "$PSScriptRoot/vmunreg.ps1"
})

$Window.ShowDialog() | Out-Null
