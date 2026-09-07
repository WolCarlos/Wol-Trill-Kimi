' ============================================================================
' Wol-Trill-Kimi — stop-notifica.vbs (Windows)
' Ferma il suono in loop in modo SILENZIOSO (nessuna finestra console).
' Usato dal tasto "Ferma suono" delle toast (protocollo woltrillkimi://stop).
' ============================================================================
On Error Resume Next
Dim wsh, temp
Set wsh = CreateObject("WScript.Shell")
temp = wsh.ExpandEnvironmentStrings("%TEMP%")
CreateObject("Scripting.FileSystemObject").DeleteFile temp & "\kimi-notify-pending.flag", True
