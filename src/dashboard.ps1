# ============================================================================
# Wol-Trill-Kimi — dashboard.ps1 (Windows)
# Dashboard grafica per configurare le notifiche: volumi, intervalli e suoni
# personalizzati (trascina un file audio sulla card o usa il tasto sfoglia).
# Legge/scrive config.json nella stessa cartella. Lancio: dashboard.vbs
# ============================================================================

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$ErrorActionPreference = "SilentlyContinue"
$base       = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFile = Join-Path $base "config.json"
$soundDir   = Join-Path $base "sounds"
$customDir  = Join-Path $soundDir "custom"
$flagFile   = Join-Path $env:TEMP "kimi-notify-pending.flag"
$AudioExts  = @(".wav", ".mp3", ".m4a", ".aac", ".ogg")

$Categories = @(
    @{ Key="request";  Emoji=[System.Char]::ConvertFromUtf32(0x1F534); Nome="Permesso richiesto";  Desc="Kimi chiede un'approvazione" }
    @{ Key="question"; Emoji=[System.Char]::ConvertFromUtf32(0x1F7E1); Nome="Domanda";             Desc="Kimi ti fa una domanda" }
    @{ Key="done";     Emoji=[System.Char]::ConvertFromUtf32(0x1F7E2); Nome="Completato";          Desc="Kimi ha finito il turno" }
    @{ Key="error";    Emoji=[System.Char]::ConvertFromUtf32(0x26D4);  Nome="Errore";              Desc="Turno o task fallito" }
    @{ Key="agent";    Emoji=[System.Char]::ConvertFromUtf32(0x1F916); Nome="Agente completato";   Desc="Un subagente ha finito" }
    @{ Key="info";     Emoji=[System.Char]::ConvertFromUtf32(0x2139);  Nome="Info";                Desc="Notifiche informative (es. task background)" }
)
$Defaults = @{
    volume   = @{ request=100; question=90; done=70; error=100; agent=60; info=50 }
    interval = @{ request=2;   question=3;  done=5;  error=0;   agent=0;  info=0 }
}

# --- Carica config ---
$cfgVolumes   = $Defaults.volume.Clone()
$cfgIntervals = $Defaults.interval.Clone()
$customFiles  = @{}
if (Test-Path $configFile) {
    try {
        $disk = Get-Content $configFile -Raw | ConvertFrom-Json
        foreach ($c in $Categories) {
            if ($disk.volume.$($c.Key)   -ne $null) { $cfgVolumes[$c.Key]   = [int]$disk.volume.$($c.Key) }
            if ($disk.interval.$($c.Key) -ne $null) { $cfgIntervals[$c.Key] = [int]$disk.interval.$($c.Key) }
            if ($disk.files.$($c.Key))              { $customFiles[$c.Key]  = "$($disk.files.$($c.Key))" }
        }
    } catch {}
}

function Save-Config {
    $out = [ordered]@{
        _commento = "Wol-Trill-Kimi — volume: 0-100. interval: secondi tra ripetizioni (0 = colpo singolo). files: suoni personalizzati (relativi a sounds/). Valido dalla prossima notifica."
        volume    = [ordered]@{}
        interval  = [ordered]@{}
        files     = [ordered]@{}
    }
    foreach ($c in $Categories) {
        $out.volume[$c.Key]   = [int]$state[$c.Key].slider.Value
        $out.interval[$c.Key] = [int]($state[$c.Key].intBox.Text -replace '[^0-9]', '')
    }
    foreach ($k in $customFiles.Keys) { $out.files[$k] = $customFiles[$k] }
    [System.IO.File]::WriteAllText($configFile, ($out | ConvertTo-Json -Depth 4))
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Wol-Trill-Kimi — Impostazioni" Width="780" SizeToContent="Height"
        WindowStartupLocation="CenterScreen" Background="#FF14161D" ResizeMode="NoResize"
        FontFamily="Segoe UI" Foreground="#FFE8EAF0">
  <Window.Resources>
    <Style TargetType="TextBlock"><Setter Property="VerticalAlignment" Value="Center"/></Style>
    <Style TargetType="Slider">
      <Setter Property="VerticalAlignment" Value="Center"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Slider">
            <Grid Margin="10,0">
              <Border Height="6" CornerRadius="3" Background="#FF333A4D" VerticalAlignment="Center"/>
              <Track VerticalAlignment="Center">
                <Track.Thumb>
                  <Thumb>
                    <Thumb.Template>
                      <ControlTemplate TargetType="Thumb">
                        <Ellipse Width="18" Height="18" Fill="#FFFFFFFF" Stroke="#FF3D7EEF" StrokeThickness="3"/>
                      </ControlTemplate>
                    </Thumb.Template>
                  </Thumb>
                </Track.Thumb>
              </Track>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="Button">
      <Setter Property="Background" Value="#FF2A2F3D"/><Setter Property="Foreground" Value="#FFE8EAF0"/>
      <Setter Property="BorderThickness" Value="0"/><Setter Property="Padding" Value="12,6"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#FF3A4152"/></Trigger>
      </Style.Triggers>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#FF222634"/><Setter Property="Foreground" Value="#FFE8EAF0"/>
      <Setter Property="BorderThickness" Value="0"/><Setter Property="Padding" Value="6,4"/>
      <Setter Property="VerticalContentAlignment" Value="Center"/><Setter Property="TextAlignment" Value="Center"/>
    </Style>
  </Window.Resources>
  <StackPanel Margin="24">
    <TextBlock FontSize="22" FontWeight="Bold" Margin="0,0,0,2"><Run Foreground="#FFFFC66D">Wol-Trill-Kimi</Run><Run> — Impostazioni</Run></TextBlock>
    <TextBlock FontSize="12" Foreground="#FF9AA0B0" Margin="0,0,0,16" TextWrapping="Wrap">Volume (0-100, indipendente per suono) e intervallo di ripetizione (secondi, 0 = suona una sola volta). Per un suono personalizzato trascina un file audio (.wav .mp3 .m4a .aac .ogg) sulla sua card, oppure usa il tasto cartella. Le modifiche valgono dalla prossima notifica.</TextBlock>
    <StackPanel Name="Rows"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,14,0,4">
      <Button Name="BtnStop" Margin="0,0,8,0">&#x23F9; Ferma suoni</Button>
      <Button Name="BtnDefaults" Margin="0,0,8,0">Ripristina default</Button>
      <Button Name="BtnSave" Background="#FF3D7EEF" FontWeight="Bold">&#x1F4BE; Salva</Button>
    </StackPanel>
    <TextBlock Name="Status" FontSize="12" Foreground="#FF7BE08B" Margin="0,6,0,0" HorizontalAlignment="Right"/>
  </StackPanel>
</Window>
"@

$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$rows   = $window.FindName("Rows")
$status = $window.FindName("Status")
$state  = @{}

function Get-SoundPath([string]$k) {
    if ($customFiles.ContainsKey($k)) {
        $p = $customFiles[$k]
        if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $soundDir $p }
        if (Test-Path $p) { return $p }
    }
    return (Join-Path $soundDir "$k.wav")
}

function Set-Status([string]$msg, [string]$color = "#FF7BE08B") {
    $status.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom($color)
    $status.Text = $msg
}

function Import-CustomSound([string]$k, [string]$sourcePath) {
    $ext = [System.IO.Path]::GetExtension($sourcePath).ToLower()
    if ($AudioExts -notcontains $ext) {
        Set-Status "Formato non supportato: $ext (usa .wav .mp3 .m4a .aac .ogg)" "#FFFF7A7A"
        return
    }
    New-Item -ItemType Directory -Force -Path $customDir | Out-Null
    $destFile = "custom/$k$ext"
    Copy-Item $sourcePath (Join-Path $customDir "$k$ext") -Force
    $customFiles[$k] = $destFile
    Save-Config
    $state[$k].customLbl.Text = [System.Char]::ConvertFromUtf32(0x1F3B5) + " " + [System.IO.Path]::GetFileName($sourcePath)
    $state[$k].resetBtn.Visibility = "Visible"
    Set-Status "Suono personalizzato assegnato a '$k'."
}

foreach ($c in $Categories) {
    $k = $c.Key

    $card = New-Object System.Windows.Controls.Border
    $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#FF1D212B")
    $card.CornerRadius = "10"; $card.Padding = "14,10"; $card.Margin = "0,0,0,10"
    $card.AllowDrop = $true; $card.Tag = $k

    $grid = New-Object System.Windows.Controls.Grid
    0..3 | ForEach-Object {
        $col = New-Object System.Windows.Controls.ColumnDefinition
        $col.Width = switch ($_) { 0 { "*" } 1 { "Auto" } 2 { "Auto" } 3 { "Auto" } }
        $grid.ColumnDefinitions.Add($col) | Out-Null
    }

    # Colonna 0: emoji + nome + descrizione + eventuale file custom
    $head = New-Object System.Windows.Controls.StackPanel
    $head.Orientation = "Horizontal"
    $tEmoji = New-Object System.Windows.Controls.TextBlock
    $tEmoji.Text = "$($c.Emoji)"; $tEmoji.FontSize = 20; $tEmoji.Margin = "0,0,10,0"
    $tEmoji.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe UI Emoji")
    $head.Children.Add($tEmoji) | Out-Null
    $nameDesc = New-Object System.Windows.Controls.StackPanel
    $tName = New-Object System.Windows.Controls.TextBlock
    $tName.Text = "$($c.Nome)"; $tName.FontSize = 14; $tName.FontWeight = "SemiBold"
    $tDesc = New-Object System.Windows.Controls.TextBlock
    $tDesc.Text = $c.Desc; $tDesc.FontSize = 11; $tDesc.TextWrapping = "Wrap"
    $tDesc.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#FF9AA0B0")
    $customLbl = New-Object System.Windows.Controls.TextBlock
    $customLbl.FontSize = 11
    $customLbl.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#FFFFC66D")
    if ($customFiles.ContainsKey($k)) {
        $customLbl.Text = [System.Char]::ConvertFromUtf32(0x1F3B5) + " " + [System.IO.Path]::GetFileName($customFiles[$k])
    }
    $nameDesc.Children.Add($tName) | Out-Null
    $nameDesc.Children.Add($tDesc) | Out-Null
    $nameDesc.Children.Add($customLbl) | Out-Null
    $head.Children.Add($nameDesc) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($head, 0)
    $grid.Children.Add($head) | Out-Null

    # Colonna 1: slider volume + badge numerico
    $volPanel = New-Object System.Windows.Controls.StackPanel
    $volPanel.Orientation = "Horizontal"; $volPanel.Margin = "14,0,0,0"
    $volLabel0 = New-Object System.Windows.Controls.TextBlock
    $volLabel0.Text = "Volume"; $volLabel0.FontSize = 11; $volLabel0.Margin = "0,0,6,0"
    $volLabel0.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#FF9AA0B0")
    $slider = New-Object System.Windows.Controls.Slider
    $slider.Width = 150
    $slider.Minimum = 0; $slider.Maximum = 100   # prima di Value: il default e' 0-10 e taglierebbe il valore
    $slider.Value = $cfgVolumes[$k]
    $badge = New-Object System.Windows.Controls.Border
    $badge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#FF222634")
    $badge.CornerRadius = "5"; $badge.Padding = "8,2"; $badge.Margin = "10,0,0,0"
    $badge.Width = 56
    $badge.HorizontalAlignment = "Left"
    $volVal = New-Object System.Windows.Controls.TextBlock
    $volVal.Text = "$([int]$slider.Value)"; $volVal.FontWeight = "Bold"
    $volVal.TextAlignment = "Center"; $volVal.TextWrapping = "NoWrap"
    $volVal.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#FF7BE08B")
    $badge.Child = $volVal
    $volPanel.Children.Add($volLabel0) | Out-Null
    $volPanel.Children.Add($slider)   | Out-Null
    $volPanel.Children.Add($badge)    | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($volPanel, 1)
    $grid.Children.Add($volPanel) | Out-Null

    # Colonna 2: intervallo
    $intPanel = New-Object System.Windows.Controls.StackPanel
    $intPanel.Orientation = "Horizontal"; $intPanel.Margin = "14,0,0,0"
    $intLabel = New-Object System.Windows.Controls.TextBlock
    $intLabel.Text = "Ogni (s)"; $intLabel.FontSize = 11; $intLabel.Margin = "0,0,8,0"
    $intLabel.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#FF9AA0B0")
    $intBox = New-Object System.Windows.Controls.TextBox
    $intBox.Width = 44; $intBox.Text = "$($cfgIntervals[$k])"
    $intPanel.Children.Add($intLabel) | Out-Null
    $intPanel.Children.Add($intBox)   | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($intPanel, 2)
    $grid.Children.Add($intPanel) | Out-Null

    # Colonna 3: Test / Sfoglia / Reset custom
    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = "Horizontal"; $btnPanel.Margin = "14,0,0,0"
    $btnTest = New-Object System.Windows.Controls.Button
    $btnTest.Content = [char]0x25B6 + " Test"; $btnTest.Tag = $k
    $btnBrowse = New-Object System.Windows.Controls.Button
    $btnBrowse.Content = [System.Char]::ConvertFromUtf32(0x1F4C2); $btnBrowse.Tag = $k
    $btnBrowse.ToolTip = "Carica un suono personalizzato (o trascinalo sulla card)"
    $btnBrowse.Margin = "6,0,0,0"
    $btnReset = New-Object System.Windows.Controls.Button
    $btnReset.Content = [char]0x21BA; $btnReset.Tag = $k
    $btnReset.ToolTip = "Torna al suono predefinito"
    $btnReset.Margin = "6,0,0,0"
    $btnReset.Visibility = $(if ($customFiles.ContainsKey($k)) { "Visible" } else { "Collapsed" })
    $btnPanel.Children.Add($btnTest)   | Out-Null
    $btnPanel.Children.Add($btnBrowse) | Out-Null
    $btnPanel.Children.Add($btnReset)  | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($btnPanel, 3)
    $grid.Children.Add($btnPanel) | Out-Null

    $card.Child = $grid
    $rows.Children.Add($card) | Out-Null
    $state[$k] = @{ slider=$slider; volVal=$volVal; intBox=$intBox; test=$btnTest; card=$card; customLbl=$customLbl; resetBtn=$btnReset; browse=$btnBrowse }
}

# --- Eventi slider / test / sfoglia / reset ---
foreach ($k in $state.Keys) {
    $s = $state[$k]
    $slider = $s.slider; $volVal = $s.volVal
    $slider.Add_ValueChanged({ $volVal.Text = "$([int]$slider.Value)" }.GetNewClosure())

    $s.test.Add_Click({
        param($sender, $e)
        $kk = $sender.Tag
        try {
            $wmp = New-Object -ComObject WMPlayer.OCX
            $wmp.settings.volume = [int]$state[$kk].slider.Value
            $wmp.URL = Get-SoundPath $kk
        } catch {}
    }.GetNewClosure())

    $s.browse.Add_Click({
        param($sender, $e)
        $kk = $sender.Tag
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Title = "Scegli un file audio per '$kk'"
        $dlg.Filter = "File audio|*.wav;*.mp3;*.m4a;*.aac;*.ogg|Tutti i file|*.*"
        if ($dlg.ShowDialog() -eq $true) { Import-CustomSound $kk $dlg.FileName }
    }.GetNewClosure())

    $s.resetBtn.Add_Click({
        param($sender, $e)
        $kk = $sender.Tag
        $customFiles.Remove($kk)
        Save-Config
        $state[$kk].customLbl.Text = ""
        $state[$kk].resetBtn.Visibility = "Collapsed"
        Set-Status "'$kk' e' tornato al suono predefinito."
    }.GetNewClosure())

    # Drag & drop sulla card
    $card = $s.card
    $card.Add_DragOver({
        param($sender, $e)
        if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
            $e.Effects = [System.Windows.DragDropEffects]::Copy
            $sender.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#FF3D7EEF")
            $sender.BorderThickness = "2"
        } else { $e.Effects = [System.Windows.DragDropEffects]::None }
        $e.Handled = $true
    })
    $card.Add_DragLeave({
        param($sender, $e)
        $sender.BorderThickness = "0"
    })
    $card.Add_Drop({
        param($sender, $e)
        $sender.BorderThickness = "0"
        $files = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
        if ($files -and $files.Count -gt 0) { Import-CustomSound $sender.Tag $files[0] }
    })
}

# --- Pulsanti globali ---
$window.FindName("BtnStop").Add_Click({
    try { Remove-Item $flagFile -Force } catch {}
    Set-Status "Suoni fermati."
})

$window.FindName("BtnDefaults").Add_Click({
    foreach ($c in $Categories) {
        $state[$c.Key].slider.Value = $Defaults.volume[$c.Key]
        $state[$c.Key].intBox.Text  = "$($Defaults.interval[$c.Key])"
    }
    Set-Status "Valori default caricati (non ancora salvati)."
})

$window.FindName("BtnSave").Add_Click({
    try {
        Save-Config
        Set-Status "Salvato. Vale dalla prossima notifica."
    } catch {
        Set-Status "Errore nel salvataggio." "#FFFF7A7A"
    }
})

$window.ShowDialog() | Out-Null
