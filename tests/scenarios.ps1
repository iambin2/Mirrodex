$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'mirrodex.ps1')
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('mirrodex-scenarios-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
$Root=$testRoot; $Cfg=Join-Path $Root 'mirrodex.cfg'; $Recovery=Join-Path $Root 'refresh-recovery.cfg'
$env:MIRRODEX_FIXTURE_DIR=$testRoot
$psExe=Join-Path $PSHOME 'powershell.exe'
if (-not (Test-Path $psExe)) { $psExe=Join-Path $PSHOME 'pwsh.exe' }
$fixture=Join-Path $PSScriptRoot 'process-fixture.ps1'
$realTool=${function:Invoke-Tool}; $realMirror=${function:Invoke-MirrorProcess}
function Invoke-Tool ($File,$Arguments,$Timeout=15000) { & $realTool $psExe (@('-NoProfile','-ExecutionPolicy','Bypass','-File',$fixture,'-Tool',$File)+$Arguments) $Timeout }
function Invoke-MirrorProcess ($File,$Arguments,$TrialSeconds=0) { & $realMirror $psExe (@('-NoProfile','-ExecutionPolicy','Bypass','-File',$fixture,'-Tool',$File)+$Arguments) $TrialSeconds }
$script:count=0; $script:prompts=New-Object 'Collections.Generic.Queue[string]'
function Assert ($Condition,$Message) { if (-not $Condition) { throw $Message }; $script:count++ }
function Queue ($Items) { foreach ($item in $Items) { $script:prompts.Enqueue($item) } }
function Show-GuideChoice ($Title,$Text,$Choices) {
  if (-not $script:prompts.Count) { throw "Unexpected prompt: $Title" }
  $pick=$script:prompts.Dequeue()
  Assert (@($Choices | Where-Object { $_.Key -eq $pick }).Count -eq 1) "Missing choice $pick in $Title"
  if ($pick -eq 'retry') { [IO.File]::WriteAllText((Join-Path $Root 'device-state'),'device'); [IO.File]::WriteAllText((Join-Path $Root 'stream-mode'),'ok') }
  return $pick
}
try {
  # External PowerShell processes emulate tools; the actual process runner is not mocked.
  [IO.File]::WriteAllText("$testRoot/device-state",'unauthorized')
  [IO.File]::WriteAllText("$testRoot/refresh",'1')
  [IO.File]::WriteAllText("$testRoot/stream-mode",'ok')
  $missing=$false; try { [void](Get-Scrcpy) } catch { $missing=$_.Exception.Message -match 'engine' }
  Assert $missing 'missing bundled engine explains re-extracting instead of installing'
  [void][IO.Directory]::CreateDirectory("$Root/engine"); foreach ($f in 'mirrodex-engine.exe','mirrodex-adb.exe') { [IO.File]::WriteAllText("$Root/engine/$f",'') }
  Assert ((Get-Scrcpy) -eq (Join-Path $Root 'engine\mirrodex-engine.exe')) 'bundled engine is used without any install'
  $scrcpy='scrcpy'; $adb='adb'
  Queue @('retry')
  Assert ((Connect-Device $adb '' ) -eq 'TEST') 'authorization prompt then reconnect'
  $device=Inspect-Device $adb $scrcpy 'TEST'
  $c=Get-StartingConfig $device 'TEST' 'usb'; $c.arr='1'
  Initialize-Context $adb 'TEST'
  Save-Config $c; Save-Profile 'good' $c
  $original=(Get-FileHash $Cfg).Hash
  Start-Mirror $scrcpy $adb $c 'TEST'
  Assert ((Get-Content "$testRoot/refresh" -Raw) -eq '1' -and -not (Test-Path $Recovery)) 'native launch restores refresh'
  Assert ($script:LastSession.Samples -eq 2 -and $script:LastSession.Min -eq 59 -and $script:LastSession.Skipped -eq 2) 'parse real child-process output'
  [IO.File]::WriteAllText("$testRoot/stream-mode",'disconnect')
  $failed=$false
  try { Start-Mirror $scrcpy $adb $c 'TEST' } catch { $failed=$_.Exception.Data['Kind'] -eq 'connection' }
  Assert ($failed -and -not (Test-Path $Recovery)) 'disconnect does not create a new refresh mutation journal'
  Write-Pairs $Recovery @{serial='TEST';previous='1'}
  Queue @('retry')
  [void](Connect-Device $adb 'TEST' -RequirePreferred)
  Restore-Refresh $adb 'TEST'
  Assert ((Get-Content "$testRoot/refresh" -Raw) -eq '1' -and -not (Test-Path $Recovery)) 'reconnect restores exact refresh state'
  [IO.File]::WriteAllText("$testRoot/stream-mode",'encoder')
  Queue @('alternate','keep')
  Start-ResilientMirror $scrcpy $adb $c 'TEST'
  Assert ((Get-FileHash $Cfg).Hash -eq $original) 'supported encoder fallback not silently saved'
  $changed=$c.Clone(); $changed.buffer='80'; Save-Config $changed
  Assert ((Read-Profile 'good' 'TEST').buffer -eq '50') 'normal save cannot overwrite pinned good'
  $restored=Complete-Guide 'restore' $changed 'TEST'
  Assert ((Import-Config).buffer -eq '50' -and (Read-PreviousConfig 'TEST').buffer -eq '80') 'restore and undo are separate'
  $undone=Complete-Guide 'undo' $restored 'TEST'
  Assert ($undone.buffer -eq '80') 'undo uses same-environment previous configuration'
  $firstContext=$script:Context.Clone()
  Initialize-Context $adb '127.0.0.1:5555'
  Assert ($script:Context.Key -ne $firstContext.Key -and -not (Read-Profile 'good' '127.0.0.1:5555')) 'wireless cannot inherit USB pinned good'
  Queue @('guide')
  Assert ($null -eq (Select-Environment $changed '127.0.0.1:5555') -and $script:GuideMode) 'changed environment proposes guide'
  $script:Context=$firstContext
  $script:LastSession=Get-SessionSummary 3 'unexpected TEST private-clipboard failure'
  $path=Export-Diagnostics $c; $text=Get-Content $path -Raw
  Assert ($text -notmatch 'TEST|private-clipboard' -and $text -match 'Samples=0') 'diagnostics allowlist excludes raw identifiers and logs'
  Assert ((Get-SessionKind 1 'Failed to create video encoder') -eq 'encoder') 'specific encoder signature'
  Assert ((Get-SessionKind 1 'unexpected failure') -eq 'unknown') 'unknown errors not guessed as encoder failure'
  # Exercise actual Forms and supervised native process; close a trial before its time limit.
  [IO.File]::WriteAllText("$testRoot/stream-mode",'ok')
  $result=Invoke-MirrorProcess $scrcpy @() 30
  Assert ($result.Canceled) 'early closing a trial cannot count as a completed comparison'
  [IO.File]::WriteAllText("$testRoot/stream-mode",'window')
  $result=Invoke-MirrorProcess $scrcpy @() 1
  Assert (-not $result.Canceled -and $result.Samples -eq 2 -and $script:TrialGeometry[2] -gt 0) 'native test window completes and geometry is captured'
  $script:SidebarEnabled=$true; $script:PanelDevice=$device; $script:ActiveConfig=$c
  $clickTimer=New-Object Windows.Forms.Timer; $clickTimer.Interval=100
  $clickTimer.Add_Tick({
    foreach ($window in @([Windows.Forms.Application]::OpenForms)) {
      if ($window.Tag -is [hashtable] -and $window.Tag.Fields -and $window.Tag.Ready) {
        if (-not $window.Tag.Settings.Visible) { $window.Tag.Expand.PerformClick() }
        $window.Tag.Fields.size.SelectedItem='1920'
        $window.Tag.Apply.PerformClick()
        $clickTimer.Stop()
      }
    }
  })
  $clickTimer.Start()
  try { $result=Invoke-MirrorProcess $scrcpy @() } finally { $clickTimer.Dispose(); $script:SidebarEnabled=$false }
  Assert ($result.Request.Config.size -eq '1920' -and -not $result.Canceled) 'live sidebar click returns reconfiguration request from actual process loop'
  Assert (@([Windows.Forms.Application]::OpenForms).Count -eq 0) 'session cleanup disposes sidebar and trial forms'
  Assert ($script:prompts.Count -eq 0) 'all planned scenario choices consumed'
  Write-Output "PASS: $script:count scenario checks ($($PSVersionTable.PSVersion))"
} finally {
  Remove-Item Env:MIRRODEX_FIXTURE_DIR -ErrorAction SilentlyContinue
  $resolved=[IO.Path]::GetFullPath($testRoot)
  if ($resolved.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'mirrodex-scenarios-*') { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
