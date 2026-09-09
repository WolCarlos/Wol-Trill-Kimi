# ============================================================================
# Wol-Trill-Kimi — dashboard.ps1 (Windows)
# Dashboard grafica per configurare volumi e intervalli delle notifiche.
# Legge/scrive config.json nella stessa cartella. Lancio: dashboard.cmd
# ============================================================================

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$ErrorActionPreference = "SilentlyContinue"
$base       = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFile = Join-Path $base "config.json"
$soundDir   = Join-Path $base "sounds"
$flagFile   = Join-Path $env:TEMP "kimi-notify-pending.flag"

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
$cfg = $Defaults
if (Test-Path $configFile) {
    try {
        $disk = Get-Content $configFile -Raw | ConvertFrom-Json
        foreach ($c in $Categories) {
            if ($disk.volume.$($c.Key)   -ne $null) { $cfg.volume[$c.Key]   = [int]$disk.volume.$($c.Key) }
            if ($disk.interval.$($c.Key) -ne $null) { $cfg.interval[$c.Key] = [int]$disk.interval.$($c.Key) }
        }
    } catch {}
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Wol-Trill-Kimi — Impostazioni" Width="640" SizeToContent="Height"
        WindowStartupLocation="CenterScreen" Background="#FF14161D" ResizeMode="NoResize"
        FontFamily="Segoe UI" Foreground="#FFE8EAF0">
  <Window.Resources>
    <Style TargetType="TextBlock"><Setter Property="VerticalAlignment" Value="Center"/></Style>
    <Style TargetType="Slider">
      <Setter Property="VerticalAlignment" Value="Center"/>
      <Setter Property="Minimum" Value="0"/><Setter Property="Maximum" Value="100"/>
      <Setter Property="TickFrequency" Value="5"/><Setter Property="IsSnapToTickEnabled" Value="True"/>
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
    <TextBlock FontSize="12" Foreground="#FF9AA0B0" Margin="0,0,0,16" TextWrapping="Wrap">Volume (0-100, indipendente per suono) e intervallo di ripetizione (secondi, 0 = suona una sola volta). Le modifiche valgono dalla prossima notifica.</TextBlock>
    <StackPanel Name="Rows"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,4">
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
$state  = @{}   # key -> @{ slider; volLabel; intervalBox }

foreach ($c in $Categories) {
    $k = $c.Key

    $card = New-Object System.Windows.Controls.Border
    $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#FF1D212B")
    $card.CornerRadius = "10"; $card.Padding = "14,10"; $card.Margin = "0,0,0,10"

    $grid = New-Object System.Windows.Controls.Grid
    0..3 | ForEach-Object {
        $col = New-Object System.Windows.Controls.ColumnDefinition
        $col.Width = switch ($_) { 0 { "2.4*" } 1 { "2.6*" } 2 { "Auto" } 3 { "Auto" } }
        $grid.ColumnDefinitions.Add($col) | Out-Null
    }

    # Colonna 0: emoji + nome + descrizione
    $head = New-Object System.Windows.Controls.StackPanel
    $head.Orientation = "Horizontal"
    $tEmoji = New-Object System.Windows.Controls.TextBlock
    $tEmoji.Text = "$($c.Emoji)"; $tEmoji.FontSize = 20; $tEmoji.Margin = "0,0,10,0"
    $tEmoji.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe UI Emoji")
    $tName = New-Object System.Windows.Controls.TextBlock
    $tName.Text = "$($c.Nome)  "; $tName.FontSize = 14; $tName.FontWeight = "SemiBold"
    $tDesc = New-Object System.Windows.Controls.TextBlock
    $tDesc.Text = $c.Desc; $tDesc.FontSize = 11; $tDesc.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#FF9AA0B0")
    $head.Children.Add($tEmoji) | Out-Null
    $nameDesc = New-Object System.Windows.Controls.StackPanel
    $nameDesc.Children.Add($tName) | Out-Null
    $nameDesc.Children.Add($tDesc) | Out-Null
    $head.Children.Add($nameDesc) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($head, 0)
    $grid.Children.Add($head) | Out-Null

    # Colonna 1: slider volume + valore
    $volPanel = New-Object System.Windows.Controls.StackPanel
    $volPanel.Orientation = "Horizontal"; $volPanel.Margin = "16,0,0,0"
    $volLabel0 = New-Object System.Windows.Controls.TextBlock
    $volLabel0.Text = "Volume"; $volLabel0.FontSize = 11; $volLabel0.Margin = "0,0,8,0"
    $volLabel0.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#FF9AA0B0")
    $slider = New-Object System.Windows.Controls.Slider
    $slider.Width = 150; $slider.Value = $cfg.volume[$k]
    $volVal = New-Object System.Windows.Controls.TextBlock
    $volVal.Text = "$([int]$slider.Value)"; $volVal.Width = 30; $volVal.TextAlignment = "Right"
    $volVal.FontWeight = "SemiBold"; $volVal.Margin = "8,0,0,0"
    $volPanel.Children.Add($volLabel0) | Out-Null
    $volPanel.Children.Add($slider)  | Out-Null
    $volPanel.Children.Add($volVal)  | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($volPanel, 1)
    $grid.Children.Add($volPanel) | Out-Null

    # Colonna 2: intervallo
    $intPanel = New-Object System.Windows.Controls.StackPanel
    $intPanel.Orientation = "Horizontal"; $intPanel.Margin = "16,0,0,0"
    $intLabel = New-Object System.Windows.Controls.TextBlock
    $intLabel.Text = "Ogni (s)"; $intLabel.FontSize = 11; $intLabel.Margin = "0,0,8,0"
    $intLabel.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#FF9AA0B0")
    $intBox = New-Object System.Windows.Controls.TextBox
    $intBox.Width = 44; $intBox.Text = "$($cfg.interval[$k])"
    $intPanel.Children.Add($intLabel) | Out-Null
    $intPanel.Children.Add($intBox)   | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($intPanel, 2)
    $grid.Children.Add($intPanel) | Out-Null

    # Colonna 3: test
    $btnTest = New-Object System.Windows.Controls.Button
    $btnTest.Content = [char]0x25B6 + " Test"; $btnTest.Margin = "16,0,0,0"
    $btnTest.Tag = $k
    [System.Windows.Controls.Grid]::SetColumn($btnTest, 3)
    $grid.Children.Add($btnTest) | Out-Null

    $card.Child = $grid
    $rows.Children.Add($card) | Out-Null
    $state[$k] = @{ slider=$slider; volVal=$volVal; intBox=$intBox; test=$btnTest }
}

# --- Eventi ---
foreach ($k in $state.Keys) {
    $s = $state[$k]
    $slider = $s.slider; $volVal = $s.volVal
    $slider.Add_ValueChanged({ $volVal.Text = "$([int]$slider.Value)" }.GetNewClosure())

    $wav = Join-Path $soundDir "$k.wav"
    $s.test.Add_Click({
        param($sender, $e)
        $kk = $sender.Tag
        $vv = [int]$state[$kk].slider.Value
        try {
            $wmp = New-Object -ComObject WMPlayer.OCX
            $wmp.settings.volume = $vv
            $wmp.URL = (Join-Path $soundDir "$kk.wav")
        } catch {}
    }.GetNewClosure())
}

$window.FindName("BtnStop").Add_Click({
    try { Remove-Item $flagFile -Force } catch {}
    $status.Text = "Suoni fermati."
})

$window.FindName("BtnDefaults").Add_Click({
    foreach ($c in $Categories) {
        $state[$c.Key].slider.Value = $Defaults.volume[$c.Key]
        $state[$c.Key].intBox.Text  = "$($Defaults.interval[$c.Key])"
    }
    $status.Text = "Valori default caricati (non ancora salvati)."
})

$window.FindName("BtnSave").Add_Click({
    $out = [ordered]@{
        _commento = "Wol-Trill-Kimi — volume: 0-100 per categoria. interval: secondi tra ripetizioni; 0 = colpo singolo. Valido dalla prossima notifica."
        volume   = [ordered]@{}
        interval = [ordered]@{}
    }
    $ok = $true
    foreach ($c in $Categories) {
        $iv = 0
        if (-not [int]::TryParse($state[$c.Key].intBox.Text, [ref]$iv) -or $iv -lt 0 -or $iv -gt 120) {
            $status.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#FFFF7A7A")
            $status.Text = "Intervallo non valido per $($c.Nome) (0-120)."
            $ok = $false; break
        }
        $out.volume[$c.Key]   = [int]$state[$c.Key].slider.Value
        $out.interval[$c.Key] = $iv
    }
    if ($ok) {
        try {
            [System.IO.File]::WriteAllText($configFile, ($out | ConvertTo-Json -Depth 4))
            $status.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#FF7BE08B")
            $status.Text = "Salvato. Vale dalla prossima notifica."
        } catch {
            $status.Text = "Errore nel salvataggio."
        }
    }
})

$window.ShowDialog() | Out-Null
