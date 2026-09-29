$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'mirrodex.ps1')
$script:checks=0
function Assert ($Value,$Message) { if (-not $Value) { throw $Message }; $script:checks++ }
foreach ($scale in @(1.0,1.25,1.5)) {
  $form=New-GuideForm '미러링이 실행 중입니다' '현재 미러링 창의 X를 눌러 닫은 뒤 도우미를 다시 열어 주십시오. 사용 중인 화면은 중단하지 않았습니다.' @(@{Key='ok';Label='확인'})
  try {
    $form.Show(); [Windows.Forms.Application]::DoEvents()
    if ($scale -ne 1) { $form.Scale((New-Object Drawing.SizeF($scale,$scale))) }
    Fit-GuideContent $form; [Windows.Forms.Application]::DoEvents()
    $layout=$form.Controls[0]; $close=$layout.Controls[$layout.Controls.Count-1]
    Assert (-not $form.CancelButton -and $close.Text -eq (T '확인')) "single action has no competing Close button at scale $scale"
    Assert ($close.Bottom -le $layout.ClientSize.Height-$layout.Padding.Bottom) "close button not clipped at scale $scale"
    Assert (-not $layout.VerticalScroll.Visible) "short prompt needs no hidden scroll at scale $scale"
    if ($scale -eq 1.25) {
      $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
      try { $form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height))); $bitmap.Save((Join-Path $PSScriptRoot 'guide-125-preview.png')) } finally { $bitmap.Dispose() }
    }
    $picture=$layout.Controls[0].Controls[0]
    Assert ($picture.Tag.Width -ge 128) "logo source is high resolution at scale $scale"
    $bitmap=New-Object Drawing.Bitmap($picture.Width,$picture.Height)
    try {
      $picture.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$picture.Width,$picture.Height)))
      $center=$bitmap.GetPixel([int]($bitmap.Width/2),[int]($bitmap.Height/2))
      Assert ($center.ToArgb() -ne $picture.BackColor.ToArgb()) "logo fills its header box at scale $scale"
    } finally { $bitmap.Dispose() }
  } finally { $form.Dispose() }
}
$temp=Join-Path ([IO.Path]::GetTempPath()) ('mirrodex-refresh-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($temp); $Root=$temp
$script:phoneMode='0'; $script:writes=0; $script:fail=$false
function Invoke-Tool ($File,$Arguments) {
  if (($Arguments -join ' ') -match 'getprop') { return @{Code=0;Text='SM-S948N'} }
  if ($Arguments[4] -eq 'get') { return @{Code=0;Text=$script:phoneMode} }
  $script:writes++
  if ($script:fail) { return @{Code=1;Text='offline'} }
  $script:phoneMode=$Arguments[-1]; return @{Code=0;Text=''}
}
try {
  $path=Join-Path $Root 'refresh-repair.cfg'
  Write-Pairs $path @{serial='TEST';model='SM-S948N';target='1'}
  Repair-RequestedRefresh 'adb' 'OTHER'
  Assert ($script:writes -eq 0 -and (Test-Path $path)) 'repair never changes a different phone'
  $script:fail=$true; $failed=$false
  try { Repair-RequestedRefresh 'adb' 'TEST' } catch { $failed=$true }
  Assert ($failed -and (Test-Path $path)) 'failed repair remains pending'
  $script:fail=$false
  Repair-RequestedRefresh 'adb' 'TEST'
  Assert ($script:phoneMode -eq '1' -and -not (Test-Path $path)) 'verified adaptive restoration completes one-time repair'
  $before=$script:writes; Repair-RequestedRefresh 'adb' 'TEST'
  Assert ($script:writes -eq $before) 'completed repair never writes again'
  Write-Output "PASS: $script:checks DPI/refresh checks ($($PSVersionTable.PSVersion))"
} finally {
  if ([IO.Path]::GetFullPath($temp).StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $temp -Leaf) -like 'mirrodex-refresh-*') { Remove-Item -LiteralPath $temp -Recurse -Force }
}
