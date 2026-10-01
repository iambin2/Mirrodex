param([string]$Tool)
$root=$env:MIRRODEX_FIXTURE_DIR
if (-not $root) { exit 99 }
$command=$args -join ' '
if ($Tool -eq 'adb') {
  $state=[IO.File]::ReadAllText((Join-Path $root 'device-state')).Trim()
  if ($command -eq 'devices -l') { [Console]::WriteLine('List of devices attached'); if ($state -ne 'absent') { [Console]::WriteLine("TEST $state model:Fixture") }; exit 0 }
  if ($state -ne 'device') { [Console]::Error.WriteLine('device offline'); exit 1 }
  if ($command -like '*getprop ro.serialno*') { [Console]::WriteLine('TEST'); exit 0 }
  if ($command -like '*wm size*') { [Console]::WriteLine("Fixture`nPhysical size: 1080x2340"); exit 0 }
  if ($command -like '*settings get*') { [Console]::WriteLine([IO.File]::ReadAllText((Join-Path $root 'refresh'))); exit 0 }
  if ($command -like '*settings put*') { [IO.File]::WriteAllText((Join-Path $root 'refresh'),$args[-1]); exit 0 }
  exit 0
}
if ($command -like '*--list-encoders*') { [Console]::WriteLine("--video-codec=h264 --video-encoder=fixture.avc (hw)`n--video-codec=h265 --video-encoder=fixture.hevc (hw)"); exit 0 }
$mode=[IO.File]::ReadAllText((Join-Path $root 'stream-mode')).Trim()
[IO.File]::WriteAllText((Join-Path $root 'engine-started'),'1')
if ($mode -eq 'disconnect') { [IO.File]::WriteAllText((Join-Path $root 'device-state'),'offline'); [Console]::Error.WriteLine('device disconnected'); exit 2 }
if ($mode -eq 'encoder' -and $command -like '*fixture.avc*') { [Console]::Error.WriteLine('Failed to create video encoder'); exit 1 }
if ($mode -eq 'unknown') { [Console]::Error.WriteLine('unexpected failure TEST private-clipboard'); exit 3 }
if ($mode -eq 'wait') { Start-Sleep -Seconds 1 }
if ($mode -eq 'window') {
  Add-Type -AssemblyName System.Windows.Forms
  $window=New-Object Windows.Forms.Form; $window.Text='Mirrodex fixture'
  # Long enough for the side menu, which is built after the engine has started, to appear beside this window.
  $clock=New-Object Windows.Forms.Timer; $clock.Interval=5000
  $clock.Add_Tick({ $window.Close() }); $clock.Start()
  try { [void]$window.ShowDialog() } finally { $clock.Dispose(); $window.Dispose() }
}
[Console]::Error.WriteLine("Texture: 1080x2340`n60 fps (+2 frames skipped)`n59 fps")
exit 0
