param([int]$StudioPid, [int]$X = 738, [int]$Y = 520)
Add-Type @"
using System; using System.Runtime.InteropServices;
public class Clk { [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
[DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e); }
"@
# Real OS clicks into the focused Studio game view at L1-L4 combo timing (0/160/320/520 ms).
# Usage: powershell -File tools/qa/jian_combo_clicks.ps1 -StudioPid <Studio pid> -X <px> -Y <px>
(New-Object -ComObject WScript.Shell).AppActivate($StudioPid) | Out-Null
Start-Sleep -Milliseconds 400
[Clk]::SetCursorPos($X, $Y) | Out-Null
$sw = [Diagnostics.Stopwatch]::StartNew()
foreach ($i in 0..3) {
  while ($sw.ElapsedMilliseconds -lt @(0, 160, 320, 520)[$i]) { }
  [Clk]::mouse_event(0x2, 0, 0, 0, [IntPtr]::Zero); Start-Sleep -Milliseconds 30; [Clk]::mouse_event(0x4, 0, 0, 0, [IntPtr]::Zero)
}
"clicked at " + $sw.ElapsedMilliseconds
