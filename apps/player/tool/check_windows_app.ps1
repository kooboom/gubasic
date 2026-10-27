# Unzips an exported Windows app (D86), opens it as a user would and checks
# that it runs: the program starts and stays open, its window has the
# project's name as its title, and the area inside the frame is the startup
# form's size. Saves a picture of the window. CI runs it on a Windows runner
# with the app that apps/ide/test/windows/export_hello_test.dart exports.
#
#   pwsh tool/check_windows_app.ps1 -Zip app.zip -Name 안녕 -Width 320 -Height 120 -Shot shot.png
param(
  [Parameter(Mandatory)] [string] $Zip,
  [Parameter(Mandatory)] [string] $Name,
  [Parameter(Mandatory)] [int] $Width,
  [Parameter(Mandatory)] [int] $Height,
  [Parameter(Mandatory)] [string] $Shot
)
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Win {
  [StructLayout(LayoutKind.Sequential)]
  public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
'@
[Win]::SetProcessDPIAware() | Out-Null

$folder = Join-Path ([IO.Path]::GetTempPath()) "gubasic-app-$PID"
Expand-Archive -Path $Zip -DestinationPath $folder -Force
$app = Join-Path $folder "$Name-windows"
$program = Join-Path $app "$Name.exe"
foreach ($file in @($program, (Join-Path $app 'project.gbz'), (Join-Path $app 'README.txt'))) {
  if (-not (Test-Path -LiteralPath $file)) { throw "The app lacks $file" }
}

$process = Start-Process -FilePath $program -WorkingDirectory $folder -PassThru
try {
  $deadline = (Get-Date).AddSeconds(60)
  do {
    Start-Sleep -Milliseconds 500
    $process.Refresh()
    if ($process.HasExited) { throw "$Name.exe ended at once, with code $($process.ExitCode)" }
  } until ($process.MainWindowHandle -ne 0 -and $process.MainWindowTitle -eq $Name -or (Get-Date) -gt $deadline)
  $window = $process.MainWindowHandle
  if ($window -eq 0) { throw "$Name.exe showed no window" }
  if ($process.MainWindowTitle -ne $Name) {
    throw "The window's title is '$($process.MainWindowTitle)', not '$Name'"
  }

  # Time for the first frames: the form appears after Form_Load.
  Start-Sleep -Seconds 5
  $process.Refresh()
  if ($process.HasExited) { throw "$Name.exe ended, with code $($process.ExitCode)" }

  $scale = [Win]::GetDpiForWindow($window) / 96.0
  $client = New-Object Win+RECT
  [Win]::GetClientRect($window, [ref] $client) | Out-Null
  $inside = "$($client.Right - $client.Left) x $($client.Bottom - $client.Top)"
  $wanted = "$([int][Math]::Round($Width * $scale)) x $([int][Math]::Round($Height * $scale))"
  "Window '$($process.MainWindowTitle)', inside its frame $inside pixels (scale $scale); the form: $wanted"

  $outer = New-Object Win+RECT
  [Win]::GetWindowRect($window, [ref] $outer) | Out-Null
  $bitmap = New-Object Drawing.Bitmap ($outer.Right - $outer.Left), ($outer.Bottom - $outer.Top)
  $graphics = [Drawing.Graphics]::FromImage($bitmap)
  $graphics.CopyFromScreen($outer.Left, $outer.Top, 0, 0, $bitmap.Size)
  $bitmap.Save($Shot, [Drawing.Imaging.ImageFormat]::Png)
  $graphics.Dispose()
  $bitmap.Dispose()

  if ($inside -ne $wanted) { throw "The window is $inside inside its frame, not $wanted" }
  "$Name.exe runs."
} finally {
  if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
  Remove-Item -Recurse -Force -LiteralPath $folder -ErrorAction SilentlyContinue
}
