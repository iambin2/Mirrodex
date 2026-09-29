. (Join-Path $PSScriptRoot 'mirrodex-lang.ps1')
# Product identity: version checked by updates and written to Settings > Apps, repository, creator card.
$script:AppVersion='2.0.0'; $script:UpdateRepo='iambin2/Mirrodex'; $script:Creator='iambin2'
# Mirrodex design system (rules: DESIGN.md). Every window is built only from these tokens and components,
# drawn over native WinForms controls so Windows keyboard, focus, screen-reader and DPI behavior is kept.

# ---- Tokens ------------------------------------------------------------------------------------------
# Theme follows the Windows app setting (Settings > Personalization > Colors), read once per process.
function Get-UiTheme {
  if (-not $script:UiTheme) {
    $script:UiTheme='light'
    try { if ((Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme -ErrorAction Stop).AppsUseLightTheme -eq 0) { $script:UiTheme='dark' } } catch {}
  }
  return $script:UiTheme
}
$script:UiPalette=@{
  light=@{
    Background='#FAFAF9'; Surface='#FFFFFF'; Text='#1F2328'; Muted='#5F6672'; Border='#E1E4E8'; BorderHover='#C9CED4'
    Primary='#234A66'; PrimaryHover='#1B3B52'; PrimaryDown='#142C3E'; OnPrimary='#FFFFFF'
    Danger='#B42318'; DangerHover='#971C13'; DangerDown='#7A160F'; OnDanger='#FFFFFF'; Success='#1F7A4D'
    Hover='#F1F3F5'; Down='#E6E9EC'; Selection='#E3EDF4'; Disabled='#EEF0F2'; DisabledText='#9AA1AA'; Focus='#3E8EB0'
  }
  dark=@{
    Background='#1B1C1E'; Surface='#25272A'; Text='#ECEDEE'; Muted='#A5AAB2'; Border='#3A3D42'; BorderHover='#50545B'
    Primary='#6AAED0'; PrimaryHover='#7EBBDA'; PrimaryDown='#5898B8'; OnPrimary='#0D1B24'
    Danger='#F08A7E'; DangerHover='#F49D93'; DangerDown='#E0766A'; OnDanger='#2A0D0A'; Success='#63C795'
    Hover='#2E3135'; Down='#373A3F'; Selection='#233B4C'; Disabled='#2A2C2F'; DisabledText='#6B7078'; Focus='#86C6E2'
  }
}
function Get-UiColor ($Name) { [Drawing.ColorTranslator]::FromHtml($script:UiPalette[(Get-UiTheme)][$Name]) }
# 4px grid. Window padding, header gap, title gap, body gap, section gap, control gap.
$script:UiSpace=@{ Window=20; Header=16; Title=8; Body=20; Section=16; Gap=8; Button=40; Compact=32; Radius=10 }
# Type scale (points, ~1.1-1.2 steps): one family, weight carries hierarchy.
$script:UiType=@{
  Caption=@(9,''); Body=@(10,''); Label=@(10,'Medium'); Section=@(9,'SemiBold'); Brand=@(13.5,'SemiBold'); Title=@(15,'SemiBold')
}
# Pretendard (Apple SF/SD Gothic Neo style) when installed; Malgun Gothic otherwise.
function New-UiFont ($Role='Body') {
  $size,$weight=$script:UiType[$Role]
  $name=('Pretendard '+$weight).Trim()
  $font=New-Object Drawing.Font($name,[float]$size)
  if ($font.Name -eq $name) { return $font }
  $font.Dispose(); return New-Object Drawing.Font('Malgun Gothic',[float]$size,$(if ($weight) {'Bold'} else {'Regular'}))
}
function New-UiPadding ([int]$Left=0,[int]$Top=0,[int]$Right=0,[int]$Bottom=0) { New-Object Windows.Forms.Padding($Left,$Top,$Right,$Bottom) }

# ---- Native helpers ----------------------------------------------------------------------------------
function Initialize-UiNative {
  if ('MirrodexDwm' -as [type]) { return }
  Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public static class MirrodexDwm {
 [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr h, int attr, ref int value, int size);
 [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
 [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)] public static extern int SetWindowTheme(IntPtr h, string app, string id);
 [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h, int msg, IntPtr w, string l);
}
// Grayscale anti-aliased GDI+ text (macOS-like, even spacing) instead of grid-fitted GDI text, which looks jagged.
// Wraps at spaces (Korean keep-all) instead of mid-word; only over-long tokens such as file paths break per character.
public class MirrodexLabel : Label {
 static readonly StringFormat Format = StringFormat.GenericTypographic;
 public MirrodexLabel() { SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true); }
 System.Collections.Generic.List<string> Wrap(Graphics g, float width) {
  var lines = new System.Collections.Generic.List<string>();
  foreach (var para in (Text ?? "").Replace(((char)13).ToString(), "").Split((char)10)) {
   string line = "";
   foreach (var word in para.Split(' ')) {
    string candidate = line.Length == 0 ? word : line + " " + word;
    if (g.MeasureString(candidate, Font, PointF.Empty, Format).Width <= width) { line = candidate; continue; }
    if (line.Length > 0) { lines.Add(line); line = ""; }
    foreach (char ch in word) {
     if (line.Length > 0 && g.MeasureString(line + ch, Font, PointF.Empty, Format).Width > width) { lines.Add(line); line = ""; }
     line += ch;
    }
   }
   lines.Add(line);
  }
  return lines;
 }
 float LimitWidth(Size proposed) {
  float limit = float.MaxValue;
  if (MaximumSize.Width > 0) limit = MaximumSize.Width;
  if (proposed.Width > 1 && proposed.Width < 100000) limit = Math.Min(limit, proposed.Width);
  if (!AutoSize) limit = Width;
  return limit == float.MaxValue ? limit : limit - Padding.Horizontal;
 }
 public override Size GetPreferredSize(Size proposed) {
  using (var g = Graphics.FromHwnd(IntPtr.Zero)) {
   var lines = Wrap(g, LimitWidth(proposed)); float w = 0;
   foreach (var l in lines) w = Math.Max(w, g.MeasureString(l, Font, PointF.Empty, Format).Width);
   return new Size((int)Math.Ceiling(w) + 2 + Padding.Horizontal, (int)Math.Ceiling(lines.Count * Font.GetHeight(g) * 1.12f) + Padding.Vertical);
  }
 }
 protected override void OnPaint(PaintEventArgs e) {
  e.Graphics.Clear(Parent != null ? Parent.BackColor : BackColor);
  e.Graphics.TextRenderingHint = TextRenderingHint.AntiAlias;
  float y = Padding.Top, step = Font.GetHeight(e.Graphics) * 1.12f;
  using (var brush = new SolidBrush(ForeColor))
   foreach (var line in Wrap(e.Graphics, Width - Padding.Horizontal)) { e.Graphics.DrawString(line, Font, brush, Padding.Left, y, Format); y += step; }
 }
}
// Fully drawn so light and dark themes share one shape: 16px rounded box, accent fill and check when on.
public class MirrodexCheckBox : CheckBox {
 public Color BoxColor = Color.White, BorderColor = Color.Gray, AccentColor = Color.SteelBlue, MarkColor = Color.White, FocusColor = Color.SteelBlue, DisabledColor = Color.Gray;
 public MirrodexCheckBox() { SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true); AutoSize = true; }
 float Scale(Graphics g) { return g.DpiX / 96f; }
 public override Size GetPreferredSize(Size proposed) {
  using (var g = Graphics.FromHwnd(IntPtr.Zero)) {
   float s = Scale(g); var t = g.MeasureString(Text ?? "", Font, PointF.Empty, StringFormat.GenericTypographic);
   return new Size((int)Math.Ceiling(24 * s + t.Width) + 4, (int)Math.Ceiling(Math.Max(22 * s, t.Height + 6)));
  }
 }
 protected override void OnPaint(PaintEventArgs e) {
  var g = e.Graphics; float s = Scale(g);
  g.Clear(Parent != null ? Parent.BackColor : BackColor);
  g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = TextRenderingHint.AntiAlias;
  float box = 16 * s, y = (Height - box) / 2f;
  var rect = new RectangleF(1, y, box, box);
  using (var path = Round(rect, 4 * s)) {
   using (var fill = new SolidBrush(Checked && Enabled ? AccentColor : BoxColor)) g.FillPath(fill, path);
   using (var pen = new Pen(Checked && Enabled ? AccentColor : (Enabled ? BorderColor : DisabledColor), 1.2f * s)) g.DrawPath(pen, path);
   if (Focused && ShowFocusCues) using (var ring = new Pen(FocusColor, 2 * s)) g.DrawPath(ring, Round(RectangleF.Inflate(rect, 2 * s, 2 * s), 6 * s));
  }
  if (Checked) using (var pen = new Pen(MarkColor, 2 * s) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round })
   g.DrawLines(pen, new[] { new PointF(rect.X + 4 * s, rect.Y + 8.5f * s), new PointF(rect.X + 7 * s, rect.Y + 11.5f * s), new PointF(rect.X + 12 * s, rect.Y + 5 * s) });
  using (var brush = new SolidBrush(Enabled ? ForeColor : DisabledColor))
  using (var sf = new StringFormat(StringFormat.GenericTypographic) { LineAlignment = StringAlignment.Center })
   g.DrawString(Text, Font, brush, new RectangleF(24 * s, 0, Width - 24 * s, Height), sf);
 }
 static GraphicsPath Round(RectangleF r, float radius) {
  var p = new GraphicsPath(); float d = radius * 2;
  p.AddArc(r.X, r.Y, d, d, 180, 90); p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
  p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90); p.AddArc(r.X, r.Bottom - d, d, d, 90, 90); p.CloseFigure(); return p;
 }
}
public class MirrodexComboBox : ComboBox {
 public Color HoverColor = Color.WhiteSmoke;
 public MirrodexComboBox() { DrawMode = DrawMode.OwnerDrawFixed; DropDownStyle = ComboBoxStyle.DropDownList; }
 protected override void OnFontChanged(EventArgs e) { base.OnFontChanged(e); ItemHeight = Font.Height + 8; }
 protected override void OnDrawItem(DrawItemEventArgs e) {
  bool hot = (e.State & DrawItemState.Selected) != 0 && (e.State & DrawItemState.ComboBoxEdit) == 0;
  using (var bg = new SolidBrush(hot ? HoverColor : BackColor)) e.Graphics.FillRectangle(bg, e.Bounds);
  if (e.Index < 0) return;
  e.Graphics.TextRenderingHint = TextRenderingHint.AntiAlias;
  using (var fg = new SolidBrush(ForeColor))
  using (var sf = new StringFormat { LineAlignment = StringAlignment.Center, Trimming = StringTrimming.EllipsisCharacter, FormatFlags = StringFormatFlags.NoWrap })
   e.Graphics.DrawString(GetItemText(Items[e.Index]), Font, fg, new RectangleF(e.Bounds.X + 4, e.Bounds.Y, e.Bounds.Width - 4, e.Bounds.Height), sf);
 }
}
// Picker rows: label left, detail (muted) under it. Items are "label<TAB>detail" strings.
public class MirrodexListBox : ListBox {
 public Color SelectionColor = Color.LightBlue, MutedColor = Color.Gray;
 public Font DetailFont;
 public MirrodexListBox() { DrawMode = DrawMode.OwnerDrawFixed; BorderStyle = BorderStyle.None; IntegralHeight = false; }
 protected override void OnFontChanged(EventArgs e) { base.OnFontChanged(e); ItemHeight = (int)(Font.Height * 2.6); }
 protected override void OnDrawItem(DrawItemEventArgs e) {
  if (e.Index < 0) return;
  bool selected = (e.State & DrawItemState.Selected) != 0;
  using (var bg = new SolidBrush(selected ? SelectionColor : BackColor)) e.Graphics.FillRectangle(bg, e.Bounds);
  e.Graphics.TextRenderingHint = TextRenderingHint.AntiAlias;
  var parts = GetItemText(Items[e.Index]).Split('\t');
  float pad = e.Bounds.Height * 0.3f, mid = e.Bounds.Y + e.Bounds.Height / 2f;
  using (var sf = new StringFormat(StringFormat.GenericTypographic) { Trimming = StringTrimming.EllipsisCharacter, FormatFlags = StringFormatFlags.NoWrap }) {
   using (var fg = new SolidBrush(ForeColor))
    e.Graphics.DrawString(parts[0], Font, fg, new RectangleF(e.Bounds.X + pad, parts.Length > 1 ? mid - Font.GetHeight(e.Graphics) : mid - Font.GetHeight(e.Graphics) / 2, e.Bounds.Width - 2 * pad, Font.GetHeight(e.Graphics) + 2), sf);
   if (parts.Length > 1) using (var mute = new SolidBrush(MutedColor))
    e.Graphics.DrawString(parts[1], DetailFont ?? Font, mute, new RectangleF(e.Bounds.X + pad, mid + 1, e.Bounds.Width - 2 * pad, Font.GetHeight(e.Graphics) + 2), sf);
  }
 }
}
'@
}
function Set-UiNativeTheme ($Control) {
  # Dark scrollbars and list chrome come from the system dark theme class; light uses the default.
  if ((Get-UiTheme) -eq 'dark') { $Control.Add_HandleCreated({ try { [void][MirrodexDwm]::SetWindowTheme($this.Handle,'DarkMode_Explorer',$null) } catch {} }) }
}

# ---- Icons -------------------------------------------------------------------------------------------
# One drawn set: 16px box, 1.6px round strokes, filled only for record/stop. No text glyphs as icons.
function Draw-UiIcon ($Graphics, [string]$Name, [Drawing.RectangleF]$Box, [Drawing.Color]$Color) {
  $s=$Box.Width/16; $x=$Box.X; $y=$Box.Y
  $pen=New-Object Drawing.Pen($Color,[float](1.6*$s)); $pen.StartCap='Round'; $pen.EndCap='Round'; $pen.LineJoin='Round'
  $brush=New-Object Drawing.SolidBrush($Color)
  function P ([double]$a,[double]$b) { New-Object Drawing.PointF([float]($x+$a*$s),[float]($y+$b*$s)) }
  try {
    switch ($Name) {
      'record' { $Graphics.FillEllipse($brush,[float]($x+3*$s),[float]($y+3*$s),[float](10*$s),[float](10*$s)) }
      'stop' { $p=New-RoundedPath (New-Object Drawing.RectangleF([float]($x+3.5*$s),[float]($y+3.5*$s),[float](9*$s),[float](9*$s))) (2*$s); $Graphics.FillPath($brush,$p); $p.Dispose() }
      'camera' {
        $p=New-RoundedPath (New-Object Drawing.RectangleF([float]($x+1.5*$s),[float]($y+4.5*$s),[float](13*$s),[float](9*$s))) (2*$s); $Graphics.DrawPath($pen,$p); $p.Dispose()
        $Graphics.DrawLines($pen,[Drawing.PointF[]]@((P 5.5 4.5),(P 6.5 2.5),(P 9.5 2.5),(P 10.5 4.5)))
        $Graphics.DrawEllipse($pen,[float]($x+5.5*$s),[float]($y+6.5*$s),[float](5*$s),[float](5*$s))
      }
      'pin' {
        $Graphics.DrawLines($pen,[Drawing.PointF[]]@((P 6 2.5),(P 10 2.5)))
        $Graphics.DrawLines($pen,[Drawing.PointF[]]@((P 7 2.5),(P 7 6.5),(P 4.5 9.5),(P 11.5 9.5),(P 9 6.5),(P 9 2.5)))
        $Graphics.DrawLine($pen,(P 8 9.5),(P 8 14))
      }
      'wifi' {
        $Graphics.DrawArc($pen,[float]($x+1*$s),[float]($y+3*$s),[float](14*$s),[float](14*$s),225,90)
        $Graphics.DrawArc($pen,[float]($x+3.5*$s),[float]($y+5.5*$s),[float](9*$s),[float](9*$s),225,90)
        $Graphics.FillEllipse($brush,[float]($x+6.8*$s),[float]($y+11*$s),[float](2.4*$s),[float](2.4*$s))
      }
      'phone' {
        $p=New-RoundedPath (New-Object Drawing.RectangleF([float]($x+4*$s),[float]($y+1.5*$s),[float](8*$s),[float](13*$s))) (2*$s); $Graphics.DrawPath($pen,$p); $p.Dispose()
        $Graphics.DrawLine($pen,(P 7 12),(P 9 12))
      }
      'plus' { $Graphics.DrawLine($pen,(P 8 3),(P 8 13)); $Graphics.DrawLine($pen,(P 3 8),(P 13 8)) }
      'screen' {
        $p=New-RoundedPath (New-Object Drawing.RectangleF([float]($x+1.5*$s),[float]($y+2.5*$s),[float](13*$s),[float](9*$s))) (1.5*$s); $Graphics.DrawPath($pen,$p); $p.Dispose()
        $Graphics.DrawLine($pen,(P 5.5 14),(P 10.5 14))
      }
      'chevron-down' { $Graphics.DrawLines($pen,[Drawing.PointF[]]@((P 4 6),(P 8 10),(P 12 6))) }
      'chevron-up' { $Graphics.DrawLines($pen,[Drawing.PointF[]]@((P 4 10),(P 8 6),(P 12 10))) }
    }
  } finally { $pen.Dispose(); $brush.Dispose() }
}
function New-RoundedPath ([Drawing.RectangleF]$Rect, [float]$Radius) {
  $d=[Math]::Min($Radius*2,[Math]::Min($Rect.Width,$Rect.Height))
  $path=New-Object Drawing.Drawing2D.GraphicsPath
  $path.AddArc($Rect.X,$Rect.Y,$d,$d,180,90)
  $path.AddArc($Rect.Right-$d,$Rect.Y,$d,$d,270,90)
  $path.AddArc($Rect.Right-$d,$Rect.Bottom-$d,$d,$d,0,90)
  $path.AddArc($Rect.X,$Rect.Bottom-$d,$d,$d,90,90)
  $path.CloseFigure(); return $path
}

# ---- Components --------------------------------------------------------------------------------------
# Button variants: primary (one per view: the expected next step), secondary, danger (stops or removes
# something), compact (header utility). Text is Korean source, translated at display time.
function New-UiButton ([string]$Text, [string]$Key='', [string]$Variant='secondary', [string]$Icon='') {
  $button=New-Object Windows.Forms.Button
  Set-UiText $button $Text; $button.Tag=$Key
  $button.FlatStyle='Flat'; $button.FlatAppearance.BorderSize=0
  $button.UseVisualStyleBackColor=$false; $button.Cursor=[Windows.Forms.Cursors]::Hand; $button.UseCompatibleTextRendering=$true
  $compact=($Variant -eq 'compact')
  $button.Font=New-UiFont $(if ($compact) {'Caption'} else {'Label'})
  # Compact buttons size to their text; WinForms already adds its own inner margin, so keep ours small.
  $button.Padding=if ($compact) { New-UiPadding 4 0 4 0 } else { New-UiPadding 14 6 14 6 }
  $button.Height=if ($compact) { $script:UiSpace.Compact } else { $script:UiSpace.Button }
  $button.MinimumSize=New-Object Drawing.Size(0,$button.Height)
  $button.Margin=New-UiPadding 0 0 0 $script:UiSpace.Gap
  $button | Add-Member -NotePropertyName MxVariant -NotePropertyValue $Variant -Force
  $button | Add-Member -NotePropertyName MxIcon -NotePropertyValue $Icon -Force
  $button.Add_Paint({ Draw-UiButton $this $_.Graphics })
  return $button
}
function Set-UiButtonStyle ($Button, [string]$Variant, [string]$Icon) {
  $Button.MxVariant=$Variant; $Button.MxIcon=$Icon; $Button.Invalidate()
}
function Draw-UiButton ($Button, $Graphics) {
  $hover=$Button.Enabled -and $Button.ClientRectangle.Contains($Button.PointToClient([Windows.Forms.Cursor]::Position))
  $down=$hover -and [Windows.Forms.Control]::MouseButtons -eq [Windows.Forms.MouseButtons]::Left
  $variant=$Button.MxVariant
  if (-not $Button.Enabled) { $fill='Disabled'; $border='Disabled'; $text='DisabledText' }
  elseif ($variant -eq 'primary') { $fill=if ($down) {'PrimaryDown'} elseif ($hover) {'PrimaryHover'} else {'Primary'}; $border=$fill; $text='OnPrimary' }
  elseif ($variant -eq 'danger') { $fill=if ($down) {'DangerDown'} elseif ($hover) {'DangerHover'} else {'Danger'}; $border=$fill; $text='OnDanger' }
  else { $fill=if ($down) {'Down'} elseif ($hover) {'Hover'} else {'Surface'}; $border=if ($hover) {'BorderHover'} else {'Border'}; $text='Text' }
  $scale=$Graphics.DpiX/96
  $Graphics.Clear($Button.Parent.BackColor)
  $Graphics.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $rect=New-Object Drawing.RectangleF(1,1,($Button.Width-2.5),($Button.Height-2.5))
  $radius=if ($variant -eq 'compact') { $rect.Height/2 } else { $script:UiSpace.Radius*$scale }
  $path=New-RoundedPath $rect $radius
  $brush=New-Object Drawing.SolidBrush(Get-UiColor $fill); $pen=New-Object Drawing.Pen((Get-UiColor $border),1)
  try {
    $Graphics.FillPath($brush,$path); $Graphics.DrawPath($pen,$path)
    # Focus ring only after keyboard navigation, like native Windows buttons.
    $cues=$Button.GetType().GetProperty('ShowFocusCues',[Reflection.BindingFlags]'NonPublic,Instance').GetValue($Button)
    if ($Button.Focused -and $cues) {
      $ring=New-Object Drawing.Pen((Get-UiColor 'Focus'),(2*$scale))
      try { $Graphics.DrawPath($ring,$path) } finally { $ring.Dispose() }
    }
  } finally { $brush.Dispose(); $pen.Dispose(); $path.Dispose() }
  $Graphics.TextRenderingHint=[Drawing.Text.TextRenderingHint]::AntiAlias
  $color=Get-UiColor $text
  $area=New-Object Drawing.RectangleF($Button.Padding.Left,0,($Button.Width-$Button.Padding.Horizontal),$Button.Height)
  $format=New-Object Drawing.StringFormat; $format.Alignment='Center'; $format.LineAlignment='Center'
  $textBrush=New-Object Drawing.SolidBrush($color)
  try {
    if ($Button.MxIcon) {
      $iconSize=16*$scale; $gap=8*$scale
      $textWidth=[Math]::Min($Graphics.MeasureString($Button.Text,$Button.Font).Width,$area.Width-$iconSize-$gap)
      $left=$area.X+($area.Width-($iconSize+$gap+$textWidth))/2
      Draw-UiIcon $Graphics $Button.MxIcon (New-Object Drawing.RectangleF([float]$left,[float](($Button.Height-$iconSize)/2),[float]$iconSize,[float]$iconSize)) $color
      $area=New-Object Drawing.RectangleF([float]($left+$iconSize+$gap),0,[float]($textWidth+2),$Button.Height)
      $format.Alignment='Near'
    }
    $Graphics.DrawString($Button.Text,$Button.Font,$textBrush,$area,$format)
  } finally { $textBrush.Dispose(); $format.Dispose() }
}
# Text roles: title (one per dialog), body, muted (secondary explanation), caption (footnotes), section (group name).
function New-UiText ([string]$Text, [string]$Role='body', [int]$MaxWidth=0) {
  $label=New-Object MirrodexLabel; $label.AutoSize=$true
  if ($MaxWidth) { $label.MaximumSize=New-Object Drawing.Size($MaxWidth,0) }
  switch ($Role) {
    'title' { $label.Font=New-UiFont 'Title'; $label.Margin=New-UiPadding 0 0 0 $script:UiSpace.Title }
    'muted' { $label.Font=New-UiFont 'Body'; $label.ForeColor=Get-UiColor 'Muted'; $label.Margin=New-UiPadding 0 0 0 $script:UiSpace.Body }
    'caption' { $label.Font=New-UiFont 'Caption'; $label.ForeColor=Get-UiColor 'Muted'; $label.Margin=New-UiPadding 0 $script:UiSpace.Gap 0 0 }
    'section' { $label.Font=New-UiFont 'Section'; $label.ForeColor=Get-UiColor 'Muted'; $label.Margin=New-UiPadding 0 $script:UiSpace.Section 0 $script:UiSpace.Gap }
    default { $label.Font=New-UiFont 'Body'; $label.Margin=New-UiPadding 0 0 0 $script:UiSpace.Gap }
  }
  Set-UiText $label $Text
  return $label
}
# Status line tones: info (muted), success, danger (errors and live recording), busy (work in progress).
function Set-UiStatus ($Label, [string]$Text, [string]$Tone='info') {
  $Label.ForeColor=Get-UiColor $(switch ($Tone) { 'success' {'Success'} 'danger' {'Danger'} default {'Muted'} })
  Set-UiText $Label $Text
}
function New-UiCheck ([string]$Text, [bool]$Checked=$false) {
  $check=New-Object MirrodexCheckBox
  $check.Font=New-UiFont 'Body'; $check.ForeColor=Get-UiColor 'Text'; $check.Cursor=[Windows.Forms.Cursors]::Hand
  $check.BoxColor=Get-UiColor 'Surface'; $check.BorderColor=Get-UiColor 'BorderHover'; $check.AccentColor=Get-UiColor 'Primary'
  $check.MarkColor=Get-UiColor 'OnPrimary'; $check.FocusColor=Get-UiColor 'Focus'; $check.DisabledColor=Get-UiColor 'DisabledText'
  $check.Checked=$Checked; $check.Margin=New-UiPadding 0 2 0 $script:UiSpace.Gap
  Set-UiText $check $Text
  return $check
}
function New-UiCombo ($Items, $Selected, [string]$Name) {
  $combo=New-Object MirrodexComboBox; $combo.Dock='Top'; $combo.FlatStyle='Flat'
  $combo.Font=New-UiFont 'Body'; $combo.HoverColor=Get-UiColor 'Hover'
  $combo.BackColor=Get-UiColor 'Surface'; $combo.ForeColor=Get-UiColor 'Text'; $combo.Cursor=[Windows.Forms.Cursors]::Hand
  $combo.FormattingEnabled=$true; $combo.Add_Format({ $_.Value=T ([string]$_.ListItem) })
  foreach ($item in $Items) { [void]$combo.Items.Add($item) }
  $combo.SelectedItem=$Selected; $combo.AccessibleName=T $Name
  Set-UiNativeTheme $combo
  return $combo
}
# Single-line input in a rounded field; the border takes the focus color while typing.
function New-UiInput ([string]$Value='', [string]$Placeholder='', [string]$Name='') {
  $frame=New-Object Windows.Forms.Panel
  $frame.Height=$script:UiSpace.Button; $frame.Dock='Top'; $frame.Margin=New-UiPadding 0 0 0 $script:UiSpace.Gap
  $frame.Padding=New-UiPadding 12 10 12 8; $frame.BackColor=(Get-UiColor 'Background')
  $box=New-Object Windows.Forms.TextBox
  $box.BorderStyle='None'; $box.Dock='Fill'; $box.Font=New-UiFont 'Body'
  $box.BackColor=Get-UiColor 'Surface'; $box.ForeColor=Get-UiColor 'Text'; $box.Text=$Value; $box.AccessibleName=T $Name
  if ($Placeholder) { $box.Add_HandleCreated({ [void][MirrodexDwm]::SendMessage($this.Handle,0x1501,[IntPtr]1,$this.Tag) }); $box.Tag=$Placeholder }
  $frame.Controls.Add($box)
  $frame.Add_Paint({
    $g=$_.Graphics; $g.SmoothingMode='AntiAlias'; $scale=$g.DpiX/96
    $rect=New-Object Drawing.RectangleF(1,1,($this.Width-2.5),($this.Height-2.5))
    $path=New-RoundedPath $rect ($script:UiSpace.Radius*$scale)
    $focused=$this.Controls[0].Focused
    $fill=New-Object Drawing.SolidBrush(Get-UiColor 'Surface'); $pen=New-Object Drawing.Pen((Get-UiColor $(if ($focused) {'Focus'} else {'BorderHover'})),$(if ($focused) {2*$scale} else {1}))
    try { $g.FillPath($fill,$path); $g.DrawPath($pen,$path) } finally { $fill.Dispose(); $pen.Dispose(); $path.Dispose() }
  })
  $box.Add_GotFocus({ $this.Parent.Invalidate() }); $box.Add_LostFocus({ $this.Parent.Invalidate() })
  $frame | Add-Member -NotePropertyName Input -NotePropertyValue $box
  return $frame
}
function New-UiList ($Items) {
  $list=New-Object MirrodexListBox
  $list.Font=New-UiFont 'Body'; $list.DetailFont=New-UiFont 'Caption'
  $list.BackColor=Get-UiColor 'Surface'; $list.ForeColor=Get-UiColor 'Text'
  $list.SelectionColor=Get-UiColor 'Selection'; $list.MutedColor=Get-UiColor 'Muted'
  $list.Dock='Top'; $list.Margin=New-UiPadding 0 0 0 $script:UiSpace.Body
  foreach ($item in $Items) { [void]$list.Items.Add($item) }
  Set-UiNativeTheme $list
  return $list
}
# Slow actions show one consistent busy state: wait cursor, disabled trigger, status text, then the result.
function Invoke-UiBusy ($Button, $Status, [string]$Message, [scriptblock]$Action) {
  $form=$Button.FindForm(); $Button.Enabled=$false; $form.UseWaitCursor=$true
  if ($Status) { Set-UiStatus $Status $Message 'busy' }
  [Windows.Forms.Application]::DoEvents()
  try { & $Action } finally { $form.UseWaitCursor=$false; $Button.Enabled=$true }
}

# ---- Window chrome -----------------------------------------------------------------------------------
function Set-ModernForm ($Form) {
  Initialize-UiNative
  # Designer order inside a suspended layout: sizes set while building are in 96-DPI units and scale once on
  # resume. Outside a suspension the form scales immediately while empty and later sizes stay unscaled.
  # Every builder calls Complete-UiForm when done.
  $Form.SuspendLayout()
  $Form.AutoScaleDimensions=New-Object Drawing.SizeF(96,96); $Form.AutoScaleMode='Dpi'
  $Form.BackColor=Get-UiColor 'Background'
  $Form.ForeColor=Get-UiColor 'Text'
  $Form.Font=New-UiFont 'Body'
  $iconPath=Join-Path $PSScriptRoot 'mirrodex.ico'
  if (Test-Path -LiteralPath $iconPath) { $Form.Icon=New-Object Drawing.Icon($iconPath); $Form.Add_Disposed({ if ($this.Icon) { $this.Icon.Dispose() } }) }
  # Windows 11: title bar matches the theme and window background, corners are rounded. Older Windows ignores this.
  $Form.Add_HandleCreated({
    try {
      $bg=Get-UiColor 'Background'; $caption=[int]$bg.R -bor ([int]$bg.G -shl 8) -bor ([int]$bg.B -shl 16); $round=2
      $dark=[int]((Get-UiTheme) -eq 'dark'); $fg=Get-UiColor 'Text'; $text=[int]$fg.R -bor ([int]$fg.G -shl 8) -bor ([int]$fg.B -shl 16)
      [void][MirrodexDwm]::DwmSetWindowAttribute($this.Handle,20,[ref]$dark,4)
      [void][MirrodexDwm]::DwmSetWindowAttribute($this.Handle,35,[ref]$caption,4)
      [void][MirrodexDwm]::DwmSetWindowAttribute($this.Handle,36,[ref]$text,4)
      [void][MirrodexDwm]::DwmSetWindowAttribute($this.Handle,33,[ref]$round,4)
    } catch {}
  })
}
function Complete-UiForm ($Form) { $Form.ResumeLayout($false) }
function New-UiLayout ($Form) {
  $layout=New-Object Windows.Forms.TableLayoutPanel
  $layout.Dock='Fill'; $layout.ColumnCount=1; $layout.AutoScroll=$true
  $layout.Padding=New-UiPadding $script:UiSpace.Window $script:UiSpace.Window $script:UiSpace.Window $script:UiSpace.Window
  [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',100)))
  Set-UiNativeTheme $layout
  $Form.Controls.Add($layout)
  return $layout
}
function Add-BrandHeader ($Layout, $Caption='Mirrodex') {
  $row=New-Object Windows.Forms.TableLayoutPanel
  $row.AutoSize=$true; $row.Dock='Fill'; $row.ColumnCount=3; $row.RowCount=1; $row.Margin=New-UiPadding 0 0 0 $script:UiSpace.Header
  [void]$row.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('AutoSize')))
  [void]$row.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',100)))
  [void]$row.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('AutoSize')))
  $picture=New-UiLogo 32
  if ($picture) {
    # Easter egg: five quick clicks on the logo open the creator card.
    $picture.Add_Click({ Register-LogoClick $this })
    $row.Controls.Add($picture,0,0)
  }
  $label=New-Object MirrodexLabel
  $label.Text=$Caption; $label.AutoSize=$true; $label.Font=New-UiFont 'Brand'; $label.Anchor='Left'
  $label.Margin=New-UiPadding $script:UiSpace.Gap 0 0 0
  $row.Controls.Add($label,1,0)
  # Language switch: re-labels the open window in place, so a running mirror session is never interrupted.
  $toggle=New-UiButton '' 'language' 'compact'
  $toggle.Text=Get-LanguageToggleText; $toggle.AccessibleName='Language / 언어'; $toggle.Anchor='Right'
  $toggle.AutoSize=$true; $toggle.Margin=New-UiPadding 0 0 0 0
  $toggle | Add-Member -NotePropertyName MxLanguageToggle -NotePropertyValue $true
  $toggle.PSObject.Properties.Remove('MxSource')
  $toggle.Add_Click({ Set-UiLanguage $(if ((Get-UiLanguage) -eq 'en') {'ko'} else {'en'}); Update-UiLanguage $this.FindForm() })
  $row.Controls.Add($toggle,2,0)
  $Layout.Controls.Add($row)
}
function New-UiLogo ([int]$Size) {
  $path=Join-Path $PSScriptRoot 'assets/mirrodex-logo.png'
  if (-not (Test-Path $path)) { return $null }
  $picture=New-Object Windows.Forms.PictureBox
  $picture.Size=New-Object Drawing.Size($Size,$Size); $picture.Margin=New-UiPadding 0 0 0 0
  $picture.Tag=[Drawing.Image]::FromFile($path); $picture.AccessibleName='Mirrodex'
  $picture.Add_Paint({
    $side=[Math]::Min($this.ClientSize.Width,$this.ClientSize.Height)
    $x=[int](($this.ClientSize.Width-$side)/2); $y=[int](($this.ClientSize.Height-$side)/2)
    $_.Graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $_.Graphics.PixelOffsetMode=[Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $_.Graphics.DrawImage($this.Tag,(New-Object Drawing.Rectangle($x,$y,$side,$side)))
  })
  $picture.Add_Disposed({ if ($this.Tag) { $this.Tag.Dispose() } })
  return $picture
}
function Register-LogoClick ($Picture) {
  $now=[DateTime]::UtcNow
  if (-not $Picture.PSObject.Properties['MxClicks']) { $Picture | Add-Member -NotePropertyName MxClicks -NotePropertyValue (New-Object 'Collections.Generic.List[datetime]') }
  $Picture.MxClicks.Add($now)
  [void]$Picture.MxClicks.RemoveAll([Predicate[datetime]]{ param($t) ($now-$t).TotalSeconds -gt 2 })
  if ($Picture.MxClicks.Count -ge 5) { $Picture.MxClicks.Clear(); Show-CreatorCard }
}
function Show-CreatorCard {
  $logo=New-UiLogo 96
  $logo.Anchor='None'; $logo.Margin=New-UiPadding 0 $script:UiSpace.Gap 0 $script:UiSpace.Section
  $content=@($logo)
  try {
    $pick=Show-GuideChoice "만든 사람 · $script:Creator" "Mirrodex $script:AppVersion`n휴대폰 화면을 가장 쉽게 PC로 옮기기 위해 만들었습니다.`n로고를 다섯 번이나 눌러 주셔서 고맙습니다." @(@{Key='github';Label='GitHub에서 보기'}) -Closable -Content $content
    if ($pick -eq 'github') { Start-Process "https://github.com/$script:UpdateRepo" }
  } catch [OperationCanceledException] { }
}
# The toggle names the language it switches to, each in its own script.
function Get-LanguageToggleText { if ((Get-UiLanguage) -eq 'en') { '한국어' } else { 'English' } }
function Set-UiText ($Control, [string]$Text) {
  $Control | Add-Member -NotePropertyName MxSource -NotePropertyValue $Text -Force
  $Control.Text=T $Text
}
function Update-UiLanguage ($Form) {
  $stack=New-Object Collections.Stack; $stack.Push($Form)
  while ($stack.Count) {
    $control=$stack.Pop()
    if ($control.PSObject.Properties['MxSource']) { $control.Text=T $control.MxSource }
    if ($control.PSObject.Properties['MxLanguageToggle']) { $control.Text=Get-LanguageToggleText }
    if ($control -is [Windows.Forms.ComboBox] -or $control -is [Windows.Forms.ListBox]) { $control.Invalidate() }
    foreach ($child in $control.Controls) { $stack.Push($child) }
  }
  if ($Form.PSObject.Properties['MxGuide']) { Fit-GuideContent $Form }
  if ($Form.PSObject.Properties['MxSidebar']) { Fit-Sidebar $Form }
}

# ---- Side menu ---------------------------------------------------------------------------------------
# Order follows frequency: status, quick actions, what to show, connection, folded engine settings, help.
function Get-SourceLabel ($Source) {
  switch ($Source.Kind) {
    'app' { return "앱 하나만 · $($Source.Label)" }
    'camera' { if ($Source.Facing -eq 'front') { return '전면 카메라' } else { return '후면 카메라' } }
    default { return '휴대폰 화면 전체' }
  }
}
function New-Sidebar ($Config, $Device) {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $form=New-Object Windows.Forms.Form
  Set-UiText $form 'Mirrodex 설정 · 방송에 공유하지 않는 창'
  $form | Add-Member -NotePropertyName MxSidebar -NotePropertyValue $true
  $form.StartPosition='Manual'; $form.MaximizeBox=$false
  Set-ModernForm $form
  $form.ClientSize=New-Object Drawing.Size(350,600)
  $form.MinimumSize=New-Object Drawing.Size(330,300)
  $form.TopMost=[bool]$script:AlwaysOnTop
  $layout=New-UiLayout $form
  Add-BrandHeader $layout
  $width=350-2*$script:UiSpace.Window-8
  $status=New-UiText '' 'muted' $width; $status.Margin=New-UiPadding 0 0 0 0
  $statusText="$(Get-SourceLabel $script:Source) · $($Config.size)px · 최대 $($Config.fps)fps"
  $tone='info'
  if ($script:Recording) {
    $statusText="녹화 중입니다. 중지하면 파일이 저장됩니다.`n$script:RecordFile"; $tone='danger'
    if ($Config.audio -eq 'off') { $statusText+="`n소리가 휴대폰에서 재생되므로 녹화에는 포함되지 않습니다." }
  } elseif ($script:Notice) { $statusText=$script:Notice.Text; $tone=$script:Notice.Tone; $script:Notice=$null }
  elseif ($script:LastRecording) { $statusText="녹화 파일을 저장했습니다.`n$script:LastRecording"; $tone='success' }
  Set-UiStatus $status $statusText $tone
  $layout.Controls.Add($status)
  $state=@{Config=$Config.Clone(); Device=$Device; Status=$status; Request=$null; Ready=$false; Dock=$true}

  $layout.Controls.Add((New-UiText '빠른 작업' 'section'))
  $state.Record=Add-SidebarButton $layout $(if ($script:Recording) {'녹화 중지 · 파일 저장'} else {'화면 녹화 시작'}) 'record' $(if ($script:Recording) {'danger'} else {'secondary'}) $(if ($script:Recording) {'stop'} else {'record'})
  $state.Screenshot=Add-SidebarButton $layout '스크린샷 저장' 'screenshot' 'secondary' 'camera'
  $state.OnTop=New-UiCheck '미러링 창을 항상 위에 표시' ([bool]$script:AlwaysOnTop)
  $state.OnTop.Add_CheckedChanged({ Set-AlwaysOnTop $this.Checked; $this.FindForm().TopMost=$this.Checked })
  $layout.Controls.Add($state.OnTop)
  $state.Lock=New-UiCheck '방송 중 · 재연결 잠금'
  $layout.Controls.Add($state.Lock)

  # Everything about the picture: what to show, guided tuning, then the folded engine settings.
  $layout.Controls.Add((New-UiText '화면' 'section'))
  $state.Source=Add-SidebarButton $layout '보여줄 화면 바꾸기' 'source' 'secondary' 'screen'
  $state.Guide=Add-SidebarButton $layout '도우미로 화면 맞추기' 'guide'
  $state.Expand=Add-SidebarButton $layout $(if ($script:SidebarExpanded) {'화면 설정 접기'} else {'화면 설정 펼치기'}) 'expand' 'secondary' $(if ($script:SidebarExpanded) {'chevron-up'} else {'chevron-down'})
  $settings=New-Object Windows.Forms.TableLayoutPanel
  $settings.ColumnCount=1; $settings.AutoSize=$true; $settings.Dock='Top'; $settings.Margin=New-UiPadding 0 0 0 0
  [void]$settings.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',100)))
  $settings.Visible=[bool]$script:SidebarExpanded
  $layout.Controls.Add($settings); $state.Settings=$settings
  $fields=@{}
  $specs=@(
    @('size','화면 선명도 · 긴 변 px',@(800,1024,1280,1600,1920,2340,$Device.Long)),
    @('fps','프레임 상한 · fps',@(30,60)),
    @('rate','화질 · 전송량',@('4M','6M','8M','12M','16M','20M')),
    @('buffer','영상 완충 · ms',@(0,16,33,50,80,100,150,200)),
    @('audiobuffer','소리 완충 · ms',@(30,50,80,100,150,200)),
    @('codec','화면 압축 방식',@('h264','h265')),
    @('audio','소리가 나올 곳',@('output','off')))
  foreach ($spec in $specs) {
    $row=New-Object Windows.Forms.TableLayoutPanel; $row.ColumnCount=2; $row.AutoSize=$true; $row.Dock='Top'
    [void]$row.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',58)))
    [void]$row.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',42)))
    $row.Margin=New-UiPadding 0 0 0 $script:UiSpace.Gap
    $label=New-UiText $spec[1] 'body'; $label.Anchor='Left'; $label.Margin=New-UiPadding 0 0 0 0
    $current=[string]$Config[$spec[0]]
    if (-not $current) { $current=if ($spec[0] -eq 'audio') {'output'} elseif ($spec[0] -eq 'audiobuffer') {'50'} else {''} }
    $values=@($spec[2])+@($current)
    if ($spec[0] -eq 'size') { $values=@($values | Where-Object { [int]$_ -le $Device.Long }) }
    if ($spec[0] -eq 'codec') { $values=@($values | Where-Object { $_ -eq $Config.codec -or (Get-Encoder $Device.Encoders $_) }) }
    $items=@($values | Select-Object -Unique | ForEach-Object { if ($spec[0] -eq 'audio') { if ($_ -eq 'output') {'노트북'} else {'휴대폰'} } else {[string]$_} })
    $selected=if ($spec[0] -eq 'audio') { if ($current -eq 'output') {'노트북'} else {'휴대폰'} } else {$current}
    $combo=New-UiCombo $items $selected $spec[1]
    $fields[$spec[0]]=$combo
    $row.Controls.Add($label,0,0); $row.Controls.Add($combo,1,0); $settings.Controls.Add($row)
  }
  $state.Fields=$fields
  $state.Required=New-UiCheck '방송용 · 소리 연결 실패 시 알려주기' ($Config.requireaudio -eq '1')
  $settings.Controls.Add($state.Required)
  $settings.Controls.Add((New-UiText "적용하면 화면과 소리가 잠시 다시 연결되며 이번 실행에만 쓰입니다. 계속 쓰려면 저장하십시오.`nDiscord에서 공유 창을 다시 선택해야 할 수 있습니다." 'caption' $width))
  $settings.Controls[$settings.Controls.Count-1].Margin=New-UiPadding 0 $script:UiSpace.Gap 0 $script:UiSpace.Section
  $state.Apply=Add-SidebarButton $settings '변경 적용 · 화면 재연결' 'apply' 'primary'
  $state.Save=Add-SidebarButton $settings '지금 실행 중인 설정 저장' 'save'
  $state.Restore=Add-SidebarButton $settings '정상 설정으로 복원' 'restore'

  $layout.Controls.Add((New-UiText '연결' 'section'))
  if (-not (Test-WirelessSerial $Config.serial)) { $state.Wireless=Add-SidebarButton $layout '무선으로 전환 · 케이블 없이 사용' 'wireless' 'secondary' 'wifi' }
  $state.AddDevice=Add-SidebarButton $layout '다른 휴대폰 추가 연결' 'adddevice' 'secondary' 'plus'

  # Occasional help as one row of compact buttons, so the folded menu fits a 1200px screen at 125%.
  $layout.Controls.Add((New-UiText '도움말' 'section'))
  $help=New-Object Windows.Forms.FlowLayoutPanel
  $help.AutoSize=$true; $help.Dock='Top'; $help.WrapContents=$true; $help.Margin=New-UiPadding 0 0 0 0
  foreach ($item in @(@('Discord 방송 길라잡이','help'),@('문제 정보 저장','export'),@('업데이트 확인','update'))) {
    $button=New-UiButton $item[0] $item[1] 'compact'
    $button.AutoSize=$true; $button.Margin=New-UiPadding 0 0 $script:UiSpace.Gap $script:UiSpace.Gap
    $button.Add_Click({ Invoke-SidebarAction $this })
    $help.Controls.Add($button)
    if ($item[1] -eq 'update') { $state.Update=$button }
  }
  $layout.Controls.Add($help)
  $layout.Controls.Add((New-UiText '이 창의 X는 메뉴만 최소화합니다. 미러링을 끝내려면 영상 창의 X를 누르십시오.' 'caption' $width))
  $state.Lock.Add_CheckedChanged({ $s=$this.FindForm().Tag; foreach ($b in @($s.Apply,$s.Restore,$s.Record,$s.Guide,$s.Source,$s.Wireless)) { if ($b) { $b.Enabled=-not $this.Checked } } })
  $form.Tag=$state
  $form.Add_Shown({ Fit-Sidebar $this })
  Complete-UiForm $form
  $form.Add_FormClosing({ if ($_.CloseReason -eq [Windows.Forms.CloseReason]::UserClosing) { $_.Cancel=$true; $this.WindowState='Minimized' } })
  return $form
}
function Add-SidebarButton ($Layout, [string]$Text, [string]$Key, [string]$Variant='secondary', [string]$Icon='') {
  $button=New-UiButton $Text $Key $Variant $Icon
  $button.Dock='Top'
  $button.Add_Click({ Invoke-SidebarAction $this })
  $Layout.Controls.Add($button); return $button
}
function Fit-Sidebar ($Form) {
  # Height follows content (folded or not), capped by the screen; the panel scrolls beyond that.
  $layout=$Form.Controls[0]; $layout.PerformLayout()
  $preferred=$layout.GetPreferredSize((New-Object Drawing.Size($layout.ClientSize.Width,0))).Height
  $area=[Windows.Forms.Screen]::FromControl($Form).WorkingArea
  $chrome=$Form.Height-$Form.ClientSize.Height
  $Form.ClientSize=New-Object Drawing.Size($Form.ClientSize.Width,[Math]::Min($preferred+4,$area.Height-$chrome-24))
}
function Invoke-SidebarAction ($Button) {
  $s=$Button.FindForm().Tag
  if ($Button.Tag -in @('apply','record','restore','guide','source','wireless') -and $s.Lock.Checked) { Set-UiStatus $s.Status '방송 잠금을 먼저 해제해 주십시오.' 'danger'; return }
  try {
    switch ($Button.Tag) {
      'expand' {
        $script:SidebarExpanded=-not $s.Settings.Visible
        $s.Settings.Visible=$script:SidebarExpanded
        Set-UiText $Button $(if ($script:SidebarExpanded) {'화면 설정 접기'} else {'화면 설정 펼치기'})
        Set-UiButtonStyle $Button 'secondary' $(if ($script:SidebarExpanded) {'chevron-up'} else {'chevron-down'})
        Fit-Sidebar $Button.FindForm()
      }
      'apply' { $candidate=Get-SidebarConfig $s; $s.Request=@{Kind='apply';Config=$candidate} }
      'record' { $s.Request=@{Kind='record'} }
      'guide' { $s.Request=@{Kind='guide'} }
      'source' { $source=Select-MirrorSource $s.Config.serial; if ($source) { $s.Request=@{Kind='source';Source=$source} } }
      'wireless' {
        Invoke-UiBusy $Button $s.Status '무선 연결로 전환하는 중입니다…' {
          $serial=Switch-ToWireless $env:ADB $s.Config.serial
          $script:Notice=@{Text='무선으로 전환했습니다. 이제 케이블을 뽑아도 됩니다.';Tone='success'}
          $s.Request=@{Kind='serial';Serial=$serial}
        }
      }
      'adddevice' { $message=Start-AdditionalDevice $s.Config.serial; Set-UiStatus $s.Status $message 'info' }
      'screenshot' { Invoke-UiBusy $Button $s.Status '스크린샷을 저장하는 중입니다…' { $path=Save-Screenshot $s.Config.serial; Set-UiStatus $s.Status "스크린샷을 저장했습니다.`n$path" 'success' } }
      'save' { Save-Config $s.Config; Set-UiStatus $s.Status '지금 실행 중인 설정을 저장했습니다. 아직 적용하지 않은 선택값은 저장하지 않습니다.' 'success' }
      'restore' { $candidate=Read-Profile 'good' $s.Config.serial; if (-not $candidate) { throw '저장된 정상 설정이 없습니다. 도우미에서 먼저 화면을 확인해 주십시오.' }; $s.Request=@{Kind='apply';Config=$candidate} }
      'help' { Show-BroadcastHelp }
      'update' { Invoke-UiBusy $Button $s.Status '업데이트를 확인하는 중입니다…' { try { $r=Get-UpdateStatus; Set-UiStatus $s.Status $r.Text $r.Tone } catch { Set-UiStatus $s.Status '업데이트를 확인하지 못했습니다. 인터넷 연결을 확인해 주십시오.' 'danger' } } }
      'export' { $path=Export-Diagnostics $s.Config; Set-UiStatus $s.Status "문제 정보를 저장했습니다.`n$path" 'success' }
    }
  } catch { Set-UiStatus $s.Status $_.Exception.Message 'danger' }
}
function Get-SidebarConfig ($State) {
  $c=$State.Config.Clone()
  foreach ($key in $State.Fields.Keys) { $c[$key]=[string]$State.Fields[$key].SelectedItem }
  $c.audio=if ($c.audio -eq '노트북') {'output'} else {'off'}
  $c.requireaudio=if ($State.Required.Checked -and $c.audio -eq 'output') {'1'} else {'0'}
  if ($c.codec -ne $State.Config.codec) {
    $c.encoder=Get-Encoder $State.Device.Encoders $c.codec
    if (-not $c.encoder) { throw '지원되는 인코더가 없습니다.' }
  }
  if (-not $c.size -or [int]$c.size -gt $State.Device.Long) { throw '휴대폰 출력보다 큰 해상도는 선택할 수 없습니다.' }
  return $c
}
function Show-BroadcastHelp {
  [void](Show-GuideChoice 'Discord로 함께 보기' "1. Windows Discord에서 화면 공유 → Mirrodex 영상 창을 선택하십시오. 설정 창이나 전체 바탕화면은 선택하지 마십시오.`n`n2. 소리 공유를 켜고, 계정에서 제공하는 해상도·프레임을 선택하십시오. Mirrodex의 60fps가 Discord의 60fps를 보장하지는 않습니다.`n`n3. 알림을 숨기려면 메뉴의 '보여줄 화면 바꾸기'에서 앱 하나만 방송하십시오. 헤드폰을 쓰면 마이크로 소리가 다시 들어가는 것을 줄일 수 있습니다.`n`n4. 짧은 시험 방송에서 시청자에게 소리·입모양·끊김을 확인받으십시오. 시작 전 설정을 맞추고 '방송 중' 잠금을 켜십시오.`n`n끊길 때: 먼저 1920px, 필요하면 1600px로 낮춰 보십시오. 프레임은 유지할 수 있습니다. 자글자글하면 전송량을 한 단계 올려 비교하십시오." @(@{Key='ok';Label='설정으로 돌아가기'}))
}

# Declare DPI awareness when the UI loads, before any Form object or screen query exists.
# Declared later, the first window of the process skips its scaling (seen at 125%: too small) while later ones scale.
Initialize-UiNative; try { [void][MirrodexDwm]::SetProcessDPIAware() } catch {}
