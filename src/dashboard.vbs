' ============================================================================
' Wol-Trill-Kimi — dashboard.vbs (Windows)
' Lancia la dashboard impostazioni senza finestra console. Doppio click.
' ============================================================================
Dim wsh, fso, dir
Set fso = CreateObject("Scripting.FileSystemObject")
dir = fso.GetParentFolderName(WScript.ScriptFullName)
Set wsh = CreateObject("WScript.Shell")
wsh.Run "powershell.exe -STA -NoProfile -ExecutionPolicy Bypass -File """ & dir & "\dashboard.ps1""", 0, False
