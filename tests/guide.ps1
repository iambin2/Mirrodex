$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'mirrodex.ps1')
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('mirrodex-guide-tests-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($testRoot)
$Cfg=Join-Path $testRoot 'mirrodex.cfg'; $Recovery=Join-Path $testRoot 'recovery.cfg'
$script:count=0
function Assert ($Condition,$Message) { if (-not $Condition) { throw $Message }; $script:count++ }
$device=@{Model='SM-S948N';Long=2340;Short=1080;Encoders="--video-codec=h264 --video-encoder=vendor.avc (hw)`n--video-codec=h265 --video-encoder=vendor.hevc (hw)"}
function Answers ($Items) {
  $script:answers=New-Object 'Collections.Generic.Queue[string]'
  foreach ($item in $Items) { $script:answers.Enqueue($item) }
  $script:mirrors=0; $script:failAt=0
}
function Show-GuideChoice ($Title,$Text,$Choices) {
  if (-not $script:answers.Count) { throw "Unexpected prompt: $Title" }
  $answer=$script:answers.Dequeue()
  if ($answer -eq 'CANCEL') { throw [OperationCanceledException]::new('cancel') }
  Assert (@($Choices | Where-Object { $_.Key -eq $answer }).Count -eq 1) "Unknown choice $answer for $Title"
  return $answer
}
function Show-GuidePicker ($Title,$Text,$Items) {
  if (-not $script:answers.Count) { throw "Unexpected picker: $Title" }
  $answer=$script:answers.Dequeue()
  if ($answer -eq 'CANCEL') { return $null }
  Assert (@($Items | Where-Object { $_.Key -eq $answer }).Count -eq 1) "Unknown item $answer for $Title"
  return $answer
}
function Start-Mirror ($Scrcpy,$Adb,$Config,$Serial,[int]$TrialSeconds=0) {
  Assert ($TrialSeconds -eq 30 -and $Serial -eq 'TEST') 'bounded selected-device preview'
  $script:mirrors++
  if ($script:mirrors -eq $script:failAt) { $failure=[Exception]::new('simulated encoder failure'); $failure.Data['Kind']='encoder'; throw $failure }
}
try {
  Answers @('usb','CANCEL')
  $cancelled=$false
  try { Invoke-Guide 'scrcpy' 'adb' $null $device 'TEST' } catch [OperationCanceledException] { $cancelled=$true }
  Assert ($cancelled -and -not (Test-Path $Cfg)) 'fresh cancellation must not save'
  Answers @('usb','start','good','done')
  $good=Invoke-Guide 'scrcpy' 'adb' $null $device 'TEST'
  Assert ((Import-Config).size -eq '1024' -and $script:mirrors -eq 1) 'first run saves only reviewed preview'
  $hash=(Get-FileHash $Cfg).Hash
  Answers @('start','good','done')
  $same=Invoke-Guide 'scrcpy' 'adb' $good $device 'TEST'
  Assert ((Get-FileHash $Cfg).Hash -eq $hash) 'existing good config not rewritten'
  Answers @('start','stutter','compare','start','start','start','better','good','done')
  $better=Invoke-Guide 'scrcpy' 'adb' $good $device 'TEST'
  Assert ($better.buffer -eq '80' -and (Import-Config).buffer -eq '80' -and $script:mirrors -eq 4) 'symptom improvement uses ABA before persisting'
  Assert ((Read-Pairs ($Cfg+'.bak')).buffer -eq '50') 'prior good config backed up'
  $hash=(Get-FileHash $Cfg).Hash
  Answers @('start','blur','compare','start','start','start','keep','good','done')
  $kept=Invoke-Guide 'scrcpy' 'adb' $better $device 'TEST'
  Assert ((Get-FileHash $Cfg).Hash -eq $hash -and $kept.size -eq $better.size) 'uncertain comparison keeps baseline'
  Answers @('start','stutter','compare','start','back','good','done')
  $script:failAt=2
  $kept=Invoke-Guide 'scrcpy' 'adb' $better $device 'TEST'
  Assert ((Get-FileHash $Cfg).Hash -eq $hash) 'failed comparison does not save candidate'
  Answers @('start','alternate','good','done')
  $script:failAt=1
  $light=Invoke-Guide 'scrcpy' 'adb' $better $device 'TEST'
  Assert ($light.codec -ne $better.codec -and $light.size -eq $better.size -and (Import-Config).codec -eq $light.codec) 'confirmed encoder failure can try a different supported encoder'
  $tried=New-Object 'Collections.Generic.HashSet[string]'
  $a=Get-GuideCandidate $good $device 'stutter' $tried
  $b=Get-GuideCandidate $good $device 'stutter' $tried
  Assert ($a.Config.buffer -eq '80' -and $b.Config.size -eq '800') 'rejected candidate is not proposed repeatedly'
  $script:GuideMode=$true
  $script:deviceCall=0
  function Get-Devices {
    $script:deviceCall++
    if ($script:deviceCall -lt 4) { return @{Serial='TEST';State='unauthorized';Detail='model:test'} }
    return @{Serial='TEST';State='device';Detail='model:test'}
  }
  Answers @('retry','retry','retry')
  Assert ((Connect-Device 'adb' '') -eq 'TEST' -and $script:deviceCall -eq 4) 'novice can retry connection more than twice'
  function Get-Devices { @{Serial='TEST';State='device';Detail='model:Phone'}; @{Serial='OTHER';State='device';Detail='model:Tablet'} }
  Answers @('OTHER')
  Assert ((Connect-Device 'adb' '') -eq 'OTHER') 'device selection works with buttons'
  Answers @('CANCEL')
  $cancelled=$false
  try { Connect-Device 'adb' '' } catch [OperationCanceledException] { $cancelled=$true }
  Assert $cancelled 'cancel connection exits cleanly'
  $before=(Get-FileHash $Cfg).Hash
  Answers @('temporary')
  $temp=Invoke-Guide 'scrcpy' 'adb' $good $device 'TEST'
  Assert ($script:mirrors -eq 0 -and (Get-FileHash $Cfg).Hash -eq $before) 'temporary exit before preview does not save'
  Answers @('start','stutter','compare','skip','finish','temporary')
  $temp=Invoke-Guide 'scrcpy' 'adb' $good $device 'TEST'
  Assert ($script:mirrors -eq 1 -and (Get-FileHash $Cfg).Hash -eq $before) 'skipped comparison cannot save'
  $sequence=@('start')
  1..5 | ForEach-Object { $sequence+=@('stutter','compare','start','start','start','keep') }
  $sequence+=@('stutter','temporary')
  Answers $sequence
  $temp=Invoke-Guide 'scrcpy' 'adb' $good $device 'TEST'
  Assert ($script:mirrors -eq 16 -and $script:answers.Count -eq 0 -and (Get-FileHash $Cfg).Hash -eq $before) 'five comparisons lead to usable exit without loop or save'
  Answers @('restore')
  $restored=Invoke-Guide 'scrcpy' 'adb' $light $device 'TEST'
  Assert ($restored.buffer -eq '50' -and $script:mirrors -eq 0) 'one-click pinned restore before preview'
  Write-Host "PASS: $script:count guide checks ($($PSVersionTable.PSVersion))"
} finally {
  if ((Split-Path $testRoot -Leaf) -like 'mirrodex-guide-tests-*') { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
