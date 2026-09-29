. (Join-Path $PSScriptRoot 'mirrodex-lang.ps1')
# Product identity: version checked by updates and written to Settings > Apps, repository, creator card.
$script:AppVersion='2.0.0'; $script:UpdateRepo='iambin2/Mirrodex'; $script:Creator='iambin2'
# Mirrodex design system (rules: DESIGN.md). One idea runs through every window: a ruled record of what is showing
# now, and "1 or 2?" comparisons that change one thing at a time. Everything is drawn over native WinForms controls
# so Windows keyboard, focus, screen-reader, DPI and high-contrast behavior is kept.

# ---- Tokens ------------------------------------------------------------------------------------------
# Theme follows Windows: high contrast first, then the app mode (Settings > Personalization > Colors). Read once.
function Get-UiTheme {
  if (-not $script:UiTheme) {
    $script:UiTheme='light'
    try { Add-Type -AssemblyName System.Windows.Forms; if ([Windows.Forms.SystemInformation]::HighContrast) { $script:UiTheme='contrast' } } catch {}
    if ($script:UiTheme -ne 'contrast') {
      try { if ((Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme -ErrorAction Stop).AppsUseLightTheme -eq 0) { $script:UiTheme='dark' } } catch {}
    }
  }
  return $script:UiTheme
}
# Ink carries text and the one commit action; Lamp (the logo's eyes) marks anything switched on; Rec is only for
# recording; Success only for "saved". Rule is decoration, Field is the 3:1 boundary of anything you type or pick in.
$script:UiPalette=@{
  light=@{
    Background='#F3F4F6'; Surface='#FFFFFF'; Text='#15171A'; Muted='#596069'; Rule='#E1E4E8'; Field='#8D949E'
    Hover='#EDEFF2'; Down='#E1E4E8'; Selection='#E8ECF1'; Focus='#15171A'; Pencil='#596069'
    Ink='#15171A'; InkHover='#2B2F35'; InkDown='#000000'; OnInk='#FFFFFF'
    Lamp='#B47B0A'; LampTint='#FBF1D9'; Rec='#D0281B'; RecTint='#FCE9E7'; Success='#1D7446'
    Danger='#B42318'; DangerHover='#971C13'; DangerDown='#7A160F'; OnDanger='#FFFFFF'
    Disabled='#ECEEF1'; DisabledText='#8B929B'
  }
  dark=@{
    Background='#141517'; Surface='#1D1F22'; Text='#ECEDEF'; Muted='#A3A9B1'; Rule='#2C2F34'; Field='#6B727C'
    Hover='#26292D'; Down='#2F3237'; Selection='#2A3038'; Focus='#ECEDEF'; Pencil='#A3A9B1'
    Ink='#ECEDEF'; InkHover='#FFFFFF'; InkDown='#D2D5D9'; OnInk='#141517'
    Lamp='#F2B93B'; LampTint='#33291A'; Rec='#F2594B'; RecTint='#3A1D1A'; Success='#5CC28E'
    Danger='#F08A7E'; DangerHover='#F49D93'; DangerDown='#E0766A'; OnDanger='#2A0D0A'
    Disabled='#222428'; DisabledText='#636A73'
  }
  # High contrast: Windows' own colors; states stay readable through shape (filled/hollow lamp, lock glyph, dashes).
  contrast=@{
    Background='Window'; Surface='Window'; Text='WindowText'; Muted='WindowText'; Rule='WindowText'; Field='WindowText'
    Hover='Window'; Down='Window'; Selection='Window'; Focus='Highlight'; Pencil='WindowText'
    Ink='Highlight'; InkHover='Highlight'; InkDown='Highlight'; OnInk='HighlightText'
    Lamp='Highlight'; LampTint='Window'; Rec='Highlight'; RecTint='Window'; Success='WindowText'
    Danger='Highlight'; DangerHover='Highlight'; DangerDown='Highlight'; OnDanger='HighlightText'
    Disabled='Window'; DisabledText='GrayText'
  }
}
function Get-UiColor ($Name) {
  $value=$script:UiPalette[(Get-UiTheme)][$Name]
  if ($value -like '#*') { return [Drawing.ColorTranslator]::FromHtml($value) }
  return [Drawing.SystemColors]::$value
}
# 4px grid, 96-DPI units (forms scale them once). Inset is the inner padding of every bordered shape, and Indent the
# text column after a 16px icon, so icons and text line up across the Now card, keys, rows and messages.
$script:UiSpace=@{
  Window=20; Panel=16; Header=16; Title=6; Body=16; Section=16; Group=16; Gap=8; Inset=12; Indent=26
  Button=36; Compact=28; Link=26; Row=40; RowDetail=50; Choice=44; ChoiceDetail=56; Quiet=34; QuietDetail=44; Key=52; Field=128
}
# Type scale (points, ~1.15 steps). One family; weight carries hierarchy.
$script:UiType=@{
  Caption=@(9,''); Body=@(10,''); Label=@(10,'Medium'); Section=@(9,'SemiBold'); Headline=@(12,'SemiBold')
  Brand=@(11.5,'SemiBold'); Title=@(15,'SemiBold'); Numeral=@(11,'SemiBold')
}
# Pretendard when installed (one face for both languages). Otherwise the face that reads best per language:
# Malgun Gothic for Korean, Segoe UI Variable for English (GDI+ fallback would space Hangul unevenly).
$script:UiFonts=@{}
function Test-UiFontFamily ($Name) {
  if (-not $script:UiFonts.ContainsKey($Name)) {
    $font=New-Object Drawing.Font($Name,[float]10); $script:UiFonts[$Name]=($font.Name -eq $Name); $font.Dispose()
  }
  return $script:UiFonts[$Name]
}
function Get-UiFontFace ([string]$Weight) {
  if (Test-UiFontFamily 'Pretendard') { return @(("Pretendard $Weight").Trim(),'Regular') }
  if ((Get-UiLanguage) -eq 'en') {
    $face=if (Test-UiFontFamily 'Segoe UI Variable Text') { 'Segoe UI Variable Text' } else { 'Segoe UI' }
    if ($Weight -eq 'SemiBold') { $face=if ($face -eq 'Segoe UI') { 'Segoe UI Semibold' } else { 'Segoe UI Variable Text Semibold' } }
    return @($face,'Regular')
  }
  return @('Malgun Gothic',$(if ($Weight -eq 'SemiBold') {'Bold'} else {'Regular'}))
}
function New-UiFont ($Role='Body') {
  $size,$weight=$script:UiType[$Role]
  $face,$style=Get-UiFontFace $weight
  $font=New-Object Drawing.Font($face,[float]$size,[Drawing.FontStyle]$style)
  if ($font.Name -eq $face) { return $font }
  $font.Dispose(); return New-Object Drawing.Font('Malgun Gothic',[float]$size,$(if ($weight -eq 'SemiBold') {'Bold'} else {'Regular'}))
}
# Remembers each font role so a language switch can re-apply the face that suits the new language.
function Set-UiFont ($Control, [string]$Role, [string]$Property='Font') {
  if (-not $Control.PSObject.Properties['MxFonts']) { $Control | Add-Member -NotePropertyName MxFonts -NotePropertyValue @{} }
  $Control.MxFonts[$Property]=$Role; $Control.$Property=New-UiFont $Role
}
function New-UiPadding ([int]$Left=0,[int]$Top=0,[int]$Right=0,[int]$Bottom=0) { New-Object Windows.Forms.Padding($Left,$Top,$Right,$Bottom) }

# ---- Native controls ---------------------------------------------------------------------------------
function Initialize-UiNative {
  if ('MxButton' -as [type]) { return }
  Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
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
 [DllImport("user32.dll")] static extern bool SystemParametersInfo(int action, int param, ref int value, int ini);
 // Settings > Accessibility > Visual effects > Animation effects (SPI_GETCLIENTAREAANIMATION).
 public static bool Animations() { int on = 1; try { SystemParametersInfo(0x1042, 0, ref on, 0); } catch { } return on != 0; }
}
// Colors come from the PowerShell tokens once per process; controls only ask for names.
// Crisp pixels: GDI+ puts pixel centers on whole coordinates. Outlines therefore sit on whole coordinates (odd
// pens) or half coordinates (even pens), fills cover whole pixels, pen widths are whole pixels and every line of
// text starts on a whole pixel. A line drawn on x.5 smears into two half-gray pixels.
public static class MxTheme {
 static readonly Dictionary<string, Color> map = new Dictionary<string, Color>();
 public static bool Motion = true;
 // ClearType with hinting when Windows uses ClearType, like native Windows apps; grayscale otherwise.
 public static TextRenderingHint Hint = TextRenderingHint.AntiAlias;
 public static void Set(string name, Color c) { map[name] = c; }
 public static Color C(string name) { Color c; return map.TryGetValue(name, out c) ? c : Color.Magenta; }
 public static float S(Graphics g) { return g.DpiX / 96f; }
 public static int Px(float v) { return Math.Max(1, (int)Math.Round(v, MidpointRounding.AwayFromZero)); }
 public static float Snap(float v) { return (float)Math.Round(v, MidpointRounding.AwayFromZero); }
 // The path of an outline whose pen covers exactly the outermost 'pen' pixels of the box.
 public static RectangleF Edge(float x, float y, float w, float h, int pen) { float a = (pen - 1) / 2f; return new RectangleF(x + a, y + a, w - 1 - 2 * a, h - 1 - 2 * a); }
 // The path of a fill that covers exactly the pixels of the box.
 public static RectangleF Cover(float x, float y, float w, float h) { return new RectangleF(x - 0.5f, y - 0.5f, w, h); }
 public static GraphicsPath Round(RectangleF r, float radius) {
  var p = new GraphicsPath(); float d = Math.Min(radius * 2, Math.Min(r.Width, r.Height));
  if (d < 1) { p.AddRectangle(r); return p; }
  p.AddArc(r.X, r.Y, d, d, 180, 90); p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
  p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90); p.AddArc(r.X, r.Bottom - d, d, d, 90, 90); p.CloseFigure(); return p;
 }
 public static StringFormat Line() {
  var f = new StringFormat(StringFormat.GenericTypographic);
  f.Trimming = StringTrimming.EllipsisCharacter; f.FormatFlags = StringFormatFlags.NoWrap; return f;
 }
 // One line of text, vertically centered in the box, starting on a whole pixel.
 public static void Text(Graphics g, string text, Font font, Color color, RectangleF box, StringAlignment align) {
  float h = font.GetHeight(g), top = Snap(box.Y + (box.Height - h) / 2);
  using (var b = new SolidBrush(color)) using (var sf = Line()) { sf.Alignment = align; g.DrawString(text ?? "", font, b, new RectangleF(Snap(box.X), top, Math.Max(1, box.Width), h + 2), sf); }
 }
 public static float Width(Graphics g, string text, Font font) { return g.MeasureString(text ?? "", font, PointF.Empty, StringFormat.GenericTypographic).Width; }
 // Measuring uses the same text mode as painting, so wrapping and sizes agree.
 public static Graphics Measure() { var g = Graphics.FromHwnd(IntPtr.Zero); g.TextRenderingHint = Hint; return g; }
}
// One drawn set on a 16-unit grid, 1.5-unit round strokes snapped to whole pixels. Filled only where the object is a dot.
public static class MxIcons {
 public static void Draw(Graphics g, string name, RectangleF box, Color color) {
  if (string.IsNullOrEmpty(name)) return;
  float s = box.Width / 16f; int pw = MxTheme.Px(1.5f * s); float shift = pw % 2 == 0 ? 0.5f : 0f;
  float x = MxTheme.Snap(box.X) + shift, y = MxTheme.Snap(box.Y) + shift;
  var old = g.SmoothingMode; g.SmoothingMode = SmoothingMode.AntiAlias;
  Func<float, float, PointF> P = (a, b) => new PointF(x + a * s, y + b * s);
  Func<float, float, float, float, RectangleF> R = (a, b, w, h) => new RectangleF(x + a * s, y + b * s, w * s, h * s);
  using (var pen = new Pen(color, pw) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round })
  using (var brush = new SolidBrush(color)) {
   switch (name) {
    case "record": g.FillEllipse(brush, R(3, 3, 10, 10)); break;
    case "stop": using (var p = MxTheme.Round(R(3.5f, 3.5f, 9, 9), 2 * s)) g.FillPath(brush, p); break;
    case "camera":
     using (var p = MxTheme.Round(R(1.5f, 4.5f, 13, 9), 2 * s)) g.DrawPath(pen, p);
     g.DrawLines(pen, new[] { P(5.5f, 4.5f), P(6.5f, 2.5f), P(9.5f, 2.5f), P(10.5f, 4.5f) });
     g.DrawEllipse(pen, R(5.5f, 6.5f, 5, 5)); break;
    case "pin":
     g.DrawLine(pen, P(6, 2.5f), P(10, 2.5f));
     g.DrawLines(pen, new[] { P(7, 2.5f), P(7, 6.5f), P(4.5f, 9.5f), P(11.5f, 9.5f), P(9, 6.5f), P(9, 2.5f) });
     g.DrawLine(pen, P(8, 9.5f), P(8, 14)); break;
    case "wifi":
     g.DrawArc(pen, R(1, 3, 14, 14), 225, 90); g.DrawArc(pen, R(3.5f, 5.5f, 9, 9), 225, 90);
     g.FillEllipse(brush, R(6.8f, 11, 2.4f, 2.4f)); break;
    case "phone":
     using (var p = MxTheme.Round(R(4, 1.5f, 8, 13), 2 * s)) g.DrawPath(pen, p);
     g.DrawLine(pen, P(7, 12), P(9, 12)); break;
    case "plus": g.DrawLine(pen, P(8, 3), P(8, 13)); g.DrawLine(pen, P(3, 8), P(13, 8)); break;
    case "screen":
     using (var p = MxTheme.Round(R(1.5f, 2.5f, 13, 9), 1.5f * s)) g.DrawPath(pen, p);
     g.DrawLine(pen, P(5.5f, 14), P(10.5f, 14)); break;
    case "app":
     foreach (var o in new[] { P(2.5f, 2.5f), P(9, 2.5f), P(2.5f, 9), P(9, 9) })
      using (var p = MxTheme.Round(new RectangleF(o.X, o.Y, 4.5f * s, 4.5f * s), 1.2f * s)) g.DrawPath(pen, p);
     break;
    case "chevron-down": g.DrawLines(pen, new[] { P(4, 6), P(8, 10), P(12, 6) }); break;
    case "chevron-up": g.DrawLines(pen, new[] { P(4, 10), P(8, 6), P(12, 10) }); break;
    case "chevron-right": g.DrawLines(pen, new[] { P(6, 3.5f), P(10.5f, 8), P(6, 12.5f) }); break;
    case "reconnect": {
     g.DrawArc(pen, R(2.5f, 2.5f, 11, 11), -60, 300);
     double a = 240 * Math.PI / 180; float ex = x + (8 + 5.5f * (float)Math.Cos(a)) * s, ey = y + (8 + 5.5f * (float)Math.Sin(a)) * s;
     double back = Math.Atan2(-Math.Cos(a), Math.Sin(a));
     for (int k = -1; k <= 1; k += 2) g.DrawLine(pen, ex, ey, ex + (float)Math.Cos(back + k * 0.75) * 3.6f * s, ey + (float)Math.Sin(back + k * 0.75) * 3.6f * s);
     break; }
    case "lock":
     using (var p = MxTheme.Round(R(3, 7, 10, 7.5f), 1.5f * s)) g.DrawPath(pen, p);
     g.DrawArc(pen, R(5, 2, 6, 7), 180, 180); g.DrawLine(pen, P(5, 5.5f), P(5, 7)); g.DrawLine(pen, P(11, 5.5f), P(11, 7)); break;
    case "check": g.DrawLines(pen, new[] { P(3.5f, 8.5f), P(6.5f, 11.5f), P(12.5f, 4.5f) }); break;
    case "alert":
     g.DrawEllipse(pen, R(1.5f, 1.5f, 13, 13)); g.DrawLine(pen, P(8, 4.8f), P(8, 8.8f)); g.FillEllipse(brush, R(7.1f, 10.4f, 1.8f, 1.8f)); break;
    case "info":
     g.DrawEllipse(pen, R(1.5f, 1.5f, 13, 13)); g.DrawLine(pen, P(8, 7.3f), P(8, 11.3f)); g.FillEllipse(brush, R(7.1f, 4.2f, 1.8f, 1.8f)); break;
    case "clock":
     g.DrawEllipse(pen, R(1.5f, 1.5f, 13, 13)); g.DrawLines(pen, new[] { P(8, 4.5f), P(8, 8), P(10.5f, 9.5f) }); break;
    case "lens":
     g.DrawEllipse(pen, R(1.5f, 1.5f, 13, 13)); g.DrawLine(pen, P(8, 1.5f), P(8, 14.5f));
     g.FillEllipse(brush, R(4, 7, 2, 2)); break;
    case "sliders":
     g.DrawLine(pen, P(2, 4), P(14, 4)); g.DrawLine(pen, P(2, 8), P(14, 8)); g.DrawLine(pen, P(2, 12), P(14, 12));
     g.FillEllipse(brush, R(8.5f, 2.2f, 3.6f, 3.6f)); g.FillEllipse(brush, R(3.5f, 6.2f, 3.6f, 3.6f)); g.FillEllipse(brush, R(9.5f, 10.2f, 3.6f, 3.6f)); break;
    case "help":
     g.DrawEllipse(pen, R(1.5f, 1.5f, 13, 13)); g.DrawArc(pen, R(5.6f, 3.9f, 4.8f, 4.8f), 180, 270);
     g.DrawLine(pen, P(8, 8.7f), P(8, 9.4f)); g.FillEllipse(brush, R(7.1f, 11, 1.8f, 1.8f)); break;
    case "file":
     g.DrawLines(pen, new[] { P(9.5f, 1.5f), P(4, 1.5f), P(4, 14.5f), P(12.5f, 14.5f), P(12.5f, 4.5f), P(9.5f, 1.5f), P(9.5f, 4.5f), P(12.5f, 4.5f) }); break;
    case "update":
     g.DrawLine(pen, P(8, 2), P(8, 10)); g.DrawLines(pen, new[] { P(4.5f, 6.5f), P(8, 10), P(11.5f, 6.5f) });
     g.DrawLines(pen, new[] { P(2.5f, 11), P(2.5f, 14), P(13.5f, 14), P(13.5f, 11) }); break;
    case "folder":
     g.DrawLines(pen, new[] { P(1.5f, 13), P(1.5f, 3.5f), P(6, 3.5f), P(7.5f, 5.2f), P(14.5f, 5.2f), P(14.5f, 13), P(1.5f, 13) }); break;
    case "broadcast":
     g.FillEllipse(brush, R(6.4f, 6.4f, 3.2f, 3.2f));
     g.DrawArc(pen, R(4, 4, 8, 8), 135, 90); g.DrawArc(pen, R(4, 4, 8, 8), -45, 90);
     g.DrawArc(pen, R(1, 1, 14, 14), 140, 80); g.DrawArc(pen, R(1, 1, 14, 14), -40, 80); break;
    case "pencil":
     g.DrawLines(pen, new[] { P(3, 13), P(3.8f, 10.2f), P(10.8f, 3.2f), P(12.8f, 5.2f), P(5.8f, 12.2f), P(3, 13) });
     g.DrawLine(pen, P(9.3f, 4.7f), P(11.3f, 6.7f)); break;
   }
  }
  g.SmoothingMode = old;
 }
}
// Wraps at spaces (Korean keep-all); only over-long tokens such as paths break per character.
// An optional glyph sits in the icon column, the text in the text column.
public class MirrodexLabel : Label {
 static readonly StringFormat Format = StringFormat.GenericTypographic;
 public string Glyph = ""; public Color GlyphColor = Color.Empty;
 public MirrodexLabel() { SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true); }
 float Reserve(Graphics g) { return string.IsNullOrEmpty(Glyph) ? 0 : MxTheme.Snap(26 * g.DpiX / 96f); }
 List<string> Wrap(Graphics g, float width) {
  var lines = new List<string>();
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
 int Step(Graphics g) { return (int)Math.Ceiling(Font.GetHeight(g) * 1.18f); }
 public override Size GetPreferredSize(Size proposed) {
  using (var g = MxTheme.Measure()) {
   float reserve = Reserve(g), limit = LimitWidth(proposed);
   var lines = Wrap(g, limit == float.MaxValue ? limit : limit - reserve); float w = 0;
   foreach (var l in lines) w = Math.Max(w, g.MeasureString(l, Font, PointF.Empty, Format).Width);
   return new Size((int)Math.Ceiling(w + reserve) + 2 + Padding.Horizontal, lines.Count * Step(g) + Padding.Vertical);
  }
 }
 protected override void OnPaint(PaintEventArgs e) {
  var g = e.Graphics;
  g.Clear(Parent != null ? Parent.BackColor : BackColor);
  g.TextRenderingHint = MxTheme.Hint;
  float reserve = Reserve(g), y = Padding.Top, x = Padding.Left + reserve; int step = Step(g);
  if (reserve > 0) {
   float size = Math.Min(MxTheme.Snap(16 * g.DpiX / 96f), step);
   MxIcons.Draw(g, Glyph, new RectangleF(Padding.Left, y + (step - size) / 2f, size, size), GlyphColor.IsEmpty ? ForeColor : GlyphColor);
  }
  Color color = Enabled ? ForeColor : MxTheme.C("DisabledText");
  foreach (var line in Wrap(g, Width - Padding.Horizontal - reserve)) { MxTheme.Text(g, line, Font, color, new RectangleF(x, y, Width - x, step), StringAlignment.Near); y += step; }
 }
}
// Every button shape, drawn from one routine so a variant looks the same in every window.
//  primary / danger / secondary: centered commit buttons.   choice / choice-primary: command-link answers.
//  row: a line in a ruled group.   quiet: "other options".   key: quick action with an optional lamp.
//  compact: small outlined button.   link: text only.
// Text after " · " is the consequence: a second line for choice, row, quiet and key.
public static class MxPaint {
 public static string[] Split(string text) {
  text = text ?? ""; int i = text.IndexOf(" · ");
  return i < 0 ? new[] { text, "" } : new[] { text.Substring(0, i), text.Substring(i + 3) };
 }
 public static bool TwoLine(string v) { return v == "row" || v == "choice" || v == "choice-primary" || v == "quiet" || v == "key"; }
 static bool Filled(string v) { return v == "primary" || v == "choice-primary" || v == "danger"; }
 static bool Bordered(string v) { return v == "secondary" || v == "choice" || v == "compact" || v == "key"; }
 static bool Centered(string v) { return v == "primary" || v == "secondary" || v == "danger" || v == "compact"; }
 public static float Pad(string v, float s) { return MxTheme.Snap((v == "compact" ? 10 : v == "link" ? 3 : v == "quiet" ? 10 : 12) * s); }
 public static void Draw(Graphics g, ButtonBase c, string v, string icon, string trail, bool reconnects, bool locked, int lamp, bool lampOff, bool divider, bool focus, Font font, Font detailFont) {
  float s = MxTheme.S(g); bool on = c.Enabled;
  bool hot = on && c.ClientRectangle.Contains(c.PointToClient(Cursor.Position));
  bool down = hot && Control.MouseButtons == MouseButtons.Left;
  g.Clear(c.Parent != null ? c.Parent.BackColor : MxTheme.C("Background"));
  g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = MxTheme.Hint;
  string fill = null, border = null;
  bool lit = v == "key" && on && lamp > 0 && !locked;
  if (Filled(v)) { string b = v == "danger" ? "Danger" : "Ink"; fill = !on ? "Disabled" : down ? b + "Down" : hot ? b + "Hover" : b; }
  else if (Bordered(v)) {
   fill = !on ? "Surface" : down ? "Down" : hot ? "Hover" : "Surface"; border = "Rule";
   if (lit) { fill = lamp == 2 ? "RecTint" : "LampTint"; border = lamp == 2 ? "Rec" : "Lamp"; }
  }
  else if ((v == "row" || v == "quiet") && (hot || down)) fill = down ? "Down" : "Hover";
  // Rows draw their hover inset from the group's edge, on whole pixels.
  int ix = v == "row" ? MxTheme.Px(4 * s) : 0, iy = v == "row" ? MxTheme.Px(2 * s) : 0;
  float bw = c.Width - 2 * ix, bh = c.Height - 2 * iy, radius = 6 * s;
  float pad = Pad(v, s), textX = pad;
  bool hasIcon = !string.IsNullOrEmpty(icon) && !Centered(v);
  float iconSize = MxTheme.Snap((v == "link" ? 14 : 16) * s);
  if (hasIcon) textX = MxTheme.Snap(pad + iconSize + (v == "link" ? 6 : 10) * s);
  if (divider) using (var pen = new Pen(MxTheme.C("Rule"), 1)) g.DrawLine(pen, textX, 0, c.Width, 0);
  if (fill != null) using (var p = MxTheme.Round(MxTheme.Cover(ix, iy, bw, bh), radius + 0.5f)) using (var b = new SolidBrush(MxTheme.C(fill))) g.FillPath(b, p);
  if (border != null) using (var p = MxTheme.Round(MxTheme.Edge(ix, iy, bw, bh, 1), radius)) using (var pen = new Pen(MxTheme.C(border), 1)) g.DrawPath(pen, p);
  Color fg, sub;
  if (!on) fg = sub = MxTheme.C("DisabledText");
  else if (Filled(v)) { fg = MxTheme.C(v == "danger" ? "OnDanger" : "OnInk"); sub = Color.FromArgb(205, fg); }
  else if (v == "link") fg = sub = MxTheme.C(hot ? "Text" : "Muted");
  else { fg = MxTheme.C("Text"); sub = MxTheme.C("Muted"); }
  // Focus ring after keyboard navigation: on the edge of outlined shapes, inset in filled ones so it never merges.
  if (focus) {
   if (Filled(v)) {
    int fp = MxTheme.Px(1.5f * s), k = MxTheme.Px(3 * s);
    using (var p = MxTheme.Round(MxTheme.Edge(ix + k, iy + k, bw - 2 * k, bh - 2 * k, fp), Math.Max(2, radius - k))) using (var pen = new Pen(fg, fp)) g.DrawPath(pen, p);
   } else {
    int fp = MxTheme.Px(2 * s);
    using (var p = MxTheme.Round(MxTheme.Edge(ix, iy, bw, bh, fp), radius)) using (var pen = new Pen(MxTheme.C("Focus"), fp)) g.DrawPath(pen, p);
   }
  }
  string[] parts = TwoLine(v) ? Split(c.Text) : new[] { c.Text ?? "", "" };
  string mark = locked ? "lock" : reconnects ? "reconnect" : "";
  float right = c.Width - pad;
  if (Centered(v)) {
   float isz = string.IsNullOrEmpty(icon) ? 0 : MxTheme.Snap((v == "compact" ? 14 : 16) * s), gap = isz > 0 ? MxTheme.Snap(8 * s) : 0;
   float msz = mark == "" ? 0 : MxTheme.Snap(13 * s), mgap = msz > 0 ? MxTheme.Snap(6 * s) : 0;
   float tw = Math.Min(MxTheme.Width(g, parts[0], font) + 1, c.Width - 2 * pad - isz - gap - msz - mgap);
   float x0 = MxTheme.Snap((c.Width - (isz + gap + tw + mgap + msz)) / 2);
   if (isz > 0) MxIcons.Draw(g, icon, new RectangleF(x0, (c.Height - isz) / 2, isz, isz), fg);
   MxTheme.Text(g, parts[0], font, fg, new RectangleF(x0 + isz + gap, 0, tw + 1, c.Height), StringAlignment.Near);
   if (msz > 0) MxIcons.Draw(g, mark, new RectangleF(x0 + isz + gap + tw + mgap, (c.Height - msz) / 2, msz, msz), fg);
   return;
  }
  if (v == "key") {
   // Lamp: filled when on, hollow when off (shape, not only color). A lamp is state, not affordance:
   // recording stays lit even while the live lock disables the key.
   if (lamp >= 0) {
    float d = MxTheme.Snap(8 * s); var lr = new RectangleF(c.Width - pad - d, pad, d, d);
    Color lc = lamp == 2 ? MxTheme.C("Rec") : lamp == 1 ? MxTheme.C("Lamp") : on ? MxTheme.C("Field") : MxTheme.C("DisabledText");
    if (lamp > 0 && !lampOff) using (var lb = new SolidBrush(lc)) g.FillEllipse(lb, MxTheme.Cover(lr.X, lr.Y, d, d));
    else { int lp = MxTheme.Px(1.3f * s); using (var pen = new Pen(lc, lp)) g.DrawEllipse(pen, MxTheme.Edge(lr.X, lr.Y, d, d, lp)); }
   }
   if (mark != "") { float m = MxTheme.Snap(12 * s); MxIcons.Draw(g, mark, new RectangleF(c.Width - pad - m, c.Height - pad - m, m, m), sub); }
   if (lamp >= 0 || mark != "") right -= MxTheme.Snap(16 * s);
  } else {
   string t = locked ? "lock" : trail; float tsz = MxTheme.Snap(14 * s), msz = MxTheme.Snap(13 * s);
   if (!string.IsNullOrEmpty(t)) { MxIcons.Draw(g, t, new RectangleF(right - tsz, (c.Height - tsz) / 2, tsz, tsz), sub); right -= tsz + MxTheme.Snap(8 * s); }
   if (reconnects && !locked) { MxIcons.Draw(g, "reconnect", new RectangleF(right - msz, (c.Height - msz) / 2, msz, msz), sub); right -= msz + MxTheme.Snap(6 * s); }
  }
  if (hasIcon) {
   Color ic = lit ? MxTheme.C(lamp == 2 ? "Rec" : "Lamp") : fg;
   MxIcons.Draw(g, icon, new RectangleF(pad, (c.Height - iconSize) / 2, iconSize, iconSize), ic);
  }
  float w = Math.Max(1, right - textX);
  if (parts[1].Length == 0) MxTheme.Text(g, parts[0], font, fg, new RectangleF(textX, 0, w, c.Height), StringAlignment.Near);
  else {
   Font df = detailFont ?? font; float h1 = font.GetHeight(g), h2 = df.GetHeight(g), gap = MxTheme.Snap(2 * s);
   float top = MxTheme.Snap((c.Height - (h1 + h2 + gap)) / 2);
   MxTheme.Text(g, parts[0], font, fg, new RectangleF(textX, top, w, h1), StringAlignment.Near);
   MxTheme.Text(g, parts[1], df, sub, new RectangleF(textX, MxTheme.Snap(top + h1 + gap), w, h2), StringAlignment.Near);
  }
  if (v == "link" && hot) {
   float lw = Math.Min(MxTheme.Width(g, parts[0], font), w), ly = MxTheme.Snap((c.Height - font.GetHeight(g)) / 2) + MxTheme.Snap(font.GetHeight(g)) - 1;
   using (var pen = new Pen(fg, 1)) g.DrawLine(pen, textX, ly, textX + lw, ly);
  }
 }
 public static Size Measure(ButtonBase c, string v, string icon, bool mark, Font font) {
  using (var g = MxTheme.Measure()) {
   float s = g.DpiX / 96f;
   string text = TwoLine(v) ? Split(c.Text)[0] : (c.Text ?? "");
   float w = 2 * Pad(v, s) + MxTheme.Width(g, text, font) + 3 * s;
   if (!string.IsNullOrEmpty(icon)) w += (v == "compact" || v == "link" ? 14 : 16) * s + (v == "link" ? 6 : 8) * s;
   if (mark) w += 19 * s;
   if (v == "primary" || v == "secondary" || v == "danger") w = Math.Max(w, 96 * s);
   return new Size((int)Math.Ceiling(w), c.Height);
  }
 }
}
public class MxButton : Button {
 public string Variant = "secondary", Icon = "", Trail = "";
 public bool Reconnects, Locked, LampOff, Divider;
 public int Lamp = -1;
 public Font DetailFont;
 public MxButton() {
  SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
  FlatStyle = FlatStyle.Flat; FlatAppearance.BorderSize = 0; UseVisualStyleBackColor = false; Cursor = Cursors.Hand;
 }
 protected override void OnMouseEnter(EventArgs e) { base.OnMouseEnter(e); Invalidate(); }
 protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); Invalidate(); }
 protected override void OnMouseDown(MouseEventArgs e) { base.OnMouseDown(e); Invalidate(); }
 protected override void OnMouseUp(MouseEventArgs e) { base.OnMouseUp(e); Invalidate(); }
 protected override void OnPaint(PaintEventArgs e) { MxPaint.Draw(e.Graphics, this, Variant, Icon, Trail, Reconnects, Locked, Lamp, LampOff, Divider, Focused && ShowFocusCues, Font, DetailFont); }
 public override Size GetPreferredSize(Size proposed) { return MxPaint.Measure(this, Variant, Icon, Reconnects || Locked, Font); }
}
// A key that stays on (always on top, live lock): a real CheckBox, so screen readers announce checked/unchecked.
public class MxToggle : CheckBox {
 public string Variant = "key", Icon = "";
 public Font DetailFont;
 public MxToggle() {
  SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
  Appearance = Appearance.Button; FlatStyle = FlatStyle.Flat; FlatAppearance.BorderSize = 0; UseVisualStyleBackColor = false; Cursor = Cursors.Hand; AutoSize = false;
 }
 protected override void OnMouseEnter(EventArgs e) { base.OnMouseEnter(e); Invalidate(); }
 protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); Invalidate(); }
 protected override void OnCheckedChanged(EventArgs e) { base.OnCheckedChanged(e); Invalidate(); }
 protected override void OnPaint(PaintEventArgs e) { MxPaint.Draw(e.Graphics, this, Variant, Icon, "", false, false, Checked ? 1 : 0, false, false, Focused && ShowFocusCues, Font, DetailFont); }
}
// 16px rounded box, ink fill and check when on; a dashed underline marks a value that is not applied yet.
public class MirrodexCheckBox : CheckBox {
 public bool Changed;
 public MirrodexCheckBox() { SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true); AutoSize = true; }
 public override Size GetPreferredSize(Size proposed) {
  using (var g = MxTheme.Measure()) {
   float s = g.DpiX / 96f;
   return new Size((int)Math.Ceiling(26 * s + MxTheme.Width(g, Text, Font)) + 4, (int)Math.Ceiling(Math.Max(24 * s, Font.GetHeight(g) + 8)));
  }
 }
 protected override void OnCheckedChanged(EventArgs e) { base.OnCheckedChanged(e); Invalidate(); }
 protected override void OnPaint(PaintEventArgs e) {
  var g = e.Graphics; float s = MxTheme.S(g);
  g.Clear(Parent != null ? Parent.BackColor : BackColor);
  g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = MxTheme.Hint;
  float box = MxTheme.Snap(16 * s), y = (float)Math.Floor((Height - box) / 2), r = 4 * s; int pb = MxTheme.Px(1.2f * s);
  using (var path = MxTheme.Round(MxTheme.Cover(1, y, box, box), r + 0.5f)) using (var fill = new SolidBrush(Checked && Enabled ? MxTheme.C("Ink") : MxTheme.C("Surface"))) g.FillPath(fill, path);
  using (var path = MxTheme.Round(MxTheme.Edge(1, y, box, box, pb), r)) using (var pen = new Pen(Checked && Enabled ? MxTheme.C("Ink") : (Enabled ? MxTheme.C("Field") : MxTheme.C("DisabledText")), pb)) g.DrawPath(pen, path);
  if (Focused && ShowFocusCues) {
   int fp = MxTheme.Px(2 * s), k = MxTheme.Px(3 * s);
   using (var ring = new Pen(MxTheme.C("Focus"), fp)) using (var p = MxTheme.Round(MxTheme.Edge(1 - k, y - k, box + 2 * k, box + 2 * k, fp), 6 * s)) g.DrawPath(ring, p);
  }
  if (Checked) using (var pen = new Pen(Enabled ? MxTheme.C("OnInk") : MxTheme.C("DisabledText"), MxTheme.Px(2 * s)) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round })
   g.DrawLines(pen, new[] { new PointF(1 + 4 * s, y + 8.5f * s), new PointF(1 + 7 * s, y + 11.5f * s), new PointF(1 + 12 * s, y + 5 * s) });
  float tx = MxTheme.Snap(26 * s), th = Font.GetHeight(g);
  MxTheme.Text(g, Text, Font, Enabled ? MxTheme.C("Text") : MxTheme.C("DisabledText"), new RectangleF(tx, 0, Width - tx, Height), StringAlignment.Near);
  if (Changed) {
   float w = Math.Min(MxTheme.Width(g, Text, Font), Width - tx), ly = MxTheme.Snap((Height - th) / 2) + MxTheme.Snap(th);
   using (var pen = new Pen(MxTheme.C("Pencil"), 1) { DashStyle = DashStyle.Dash }) g.DrawLine(pen, tx, ly, tx + w, ly);
  }
 }
}
// Closed state fully drawn (native combos stay light in dark mode); the list stays native for keyboard behavior.
public class MirrodexComboBox : ComboBox {
 public bool Changed;
 public MirrodexComboBox() {
  DrawMode = DrawMode.OwnerDrawFixed; DropDownStyle = ComboBoxStyle.DropDownList; FlatStyle = FlatStyle.Flat;
  SetStyle(ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.ResizeRedraw, true);
 }
 protected override void OnFontChanged(EventArgs e) { base.OnFontChanged(e); ItemHeight = Font.Height + 10; }
 protected override void OnMouseEnter(EventArgs e) { base.OnMouseEnter(e); Invalidate(); }
 protected override void OnMouseLeave(EventArgs e) { base.OnMouseLeave(e); Invalidate(); }
 protected override void OnGotFocus(EventArgs e) { base.OnGotFocus(e); Invalidate(); }
 protected override void OnLostFocus(EventArgs e) { base.OnLostFocus(e); Invalidate(); }
 protected override void OnDropDownClosed(EventArgs e) { base.OnDropDownClosed(e); Invalidate(); }
 protected override void OnSelectedIndexChanged(EventArgs e) { base.OnSelectedIndexChanged(e); Invalidate(); }
 protected override void OnPaint(PaintEventArgs e) {
  var g = e.Graphics; float s = MxTheme.S(g);
  bool hot = Enabled && ClientRectangle.Contains(PointToClient(Cursor.Position)), ring = (Focused && ShowFocusCues) || DroppedDown;
  g.Clear(Parent != null ? Parent.BackColor : BackColor);
  g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = MxTheme.Hint;
  int pw = ring ? MxTheme.Px(2 * s) : 1; float r = 6 * s;
  using (var path = MxTheme.Round(MxTheme.Cover(0, 0, Width, Height), r + 0.5f)) using (var fill = new SolidBrush(!Enabled ? MxTheme.C("Disabled") : hot ? MxTheme.C("Hover") : MxTheme.C("Surface"))) g.FillPath(fill, path);
  using (var path = MxTheme.Round(MxTheme.Edge(0, 0, Width, Height, pw), r)) using (var pen = new Pen(ring ? MxTheme.C("Focus") : MxTheme.C("Field"), pw)) g.DrawPath(pen, path);
  string text = SelectedIndex >= 0 ? GetItemText(SelectedItem) : "";
  float tx = MxTheme.Snap(10 * s), tw = Width - 36 * s, th = Font.GetHeight(g);
  MxTheme.Text(g, text, Font, Enabled ? MxTheme.C("Text") : MxTheme.C("DisabledText"), new RectangleF(tx, 0, tw, Height), StringAlignment.Near);
  if (Changed) {
   float w = Math.Min(MxTheme.Width(g, text, Font), tw), ly = MxTheme.Snap((Height - th) / 2) + MxTheme.Snap(th);
   using (var pen = new Pen(MxTheme.C("Pencil"), 1) { DashStyle = DashStyle.Dash }) g.DrawLine(pen, tx, ly, tx + w, ly);
  }
  float cs = MxTheme.Snap(14 * s);
  MxIcons.Draw(g, "chevron-down", new RectangleF(Width - MxTheme.Snap(26 * s), (Height - cs) / 2f, cs, cs), Enabled ? MxTheme.C("Muted") : MxTheme.C("DisabledText"));
 }
 protected override void OnDrawItem(DrawItemEventArgs e) {
  if (e.Index < 0) return;
  bool sel = (e.State & DrawItemState.Selected) != 0;
  using (var bg = new SolidBrush(sel ? MxTheme.C("Selection") : MxTheme.C("Surface"))) e.Graphics.FillRectangle(bg, e.Bounds);
  e.Graphics.TextRenderingHint = MxTheme.Hint;
  MxTheme.Text(e.Graphics, GetItemText(Items[e.Index]), Font, MxTheme.C("Text"), new RectangleF(e.Bounds.X + 8, e.Bounds.Y, e.Bounds.Width - 12, e.Bounds.Height), StringAlignment.Near);
 }
}
// Picker rows: name, then detail (muted); ruled between rows; the chosen row also carries a check, not only a tint.
public class MirrodexListBox : ListBox {
 public Font DetailFont;
 public MirrodexListBox() { DrawMode = DrawMode.OwnerDrawFixed; BorderStyle = BorderStyle.None; IntegralHeight = false; }
 protected override void OnFontChanged(EventArgs e) { base.OnFontChanged(e); ItemHeight = (int)(Font.Height * 2.7); }
 protected override void OnDrawItem(DrawItemEventArgs e) {
  if (e.Index < 0) return;
  var g = e.Graphics; float s = MxTheme.S(g);
  bool selected = (e.State & DrawItemState.Selected) != 0;
  using (var bg = new SolidBrush(selected ? MxTheme.C("Selection") : MxTheme.C("Surface"))) g.FillRectangle(bg, e.Bounds);
  float pad = MxTheme.Snap(12 * s);
  if (e.Index > 0) using (var pen = new Pen(MxTheme.C("Rule"), 1)) g.DrawLine(pen, e.Bounds.X + pad, e.Bounds.Y, e.Bounds.Right, e.Bounds.Y);
  g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = MxTheme.Hint;
  var parts = GetItemText(Items[e.Index]).Split('\t');
  float mid = e.Bounds.Y + e.Bounds.Height / 2f, cs = MxTheme.Snap(16 * s), right = e.Bounds.Width - pad - (selected ? cs + MxTheme.Snap(6 * s) : 0);
  if (selected) MxIcons.Draw(g, "check", new RectangleF(e.Bounds.Right - pad - cs, mid - cs / 2, cs, cs), MxTheme.C("Text"));
  if (selected && Focused && (e.State & DrawItemState.NoFocusRect) == 0) {
   int fp = MxTheme.Px(1.5f * s), k = MxTheme.Px(1.5f * s);
   using (var ring = new Pen(MxTheme.C("Focus"), fp)) using (var p = MxTheme.Round(MxTheme.Edge(e.Bounds.X + k, e.Bounds.Y + k, e.Bounds.Width - 2 * k, e.Bounds.Height - 2 * k, fp), 4 * s)) g.DrawPath(ring, p);
  }
  float h = Font.GetHeight(g), dh = (DetailFont ?? Font).GetHeight(g);
  if (parts.Length > 1) {
   MxTheme.Text(g, parts[0], Font, MxTheme.C("Text"), new RectangleF(e.Bounds.X + pad, MxTheme.Snap(mid - h - s), right - pad, h), StringAlignment.Near);
   MxTheme.Text(g, parts[1], DetailFont ?? Font, MxTheme.C("Muted"), new RectangleF(e.Bounds.X + pad, MxTheme.Snap(mid + s), right - pad, dh), StringAlignment.Near);
  } else MxTheme.Text(g, parts[0], Font, MxTheme.C("Text"), new RectangleF(e.Bounds.X + pad, e.Bounds.Y, right - pad, e.Bounds.Height), StringAlignment.Near);
 }
}
// A surface with rounded corners (Border set) or a plain ruled row (TopRule). Children paint on its BackColor.
public class MxCard : TableLayoutPanel {
 public string Border = "Rule"; public bool TopRule; public float Radius = 8;
 public MxCard() { SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.ResizeRedraw | ControlStyles.UserPaint, true); }
 protected override void OnPaintBackground(PaintEventArgs e) {
  var g = e.Graphics; float s = MxTheme.S(g), r = Radius * s;
  g.Clear(Parent != null ? Parent.BackColor : MxTheme.C("Background"));
  g.SmoothingMode = SmoothingMode.AntiAlias;
  using (var p = MxTheme.Round(MxTheme.Cover(0, 0, Width, Height), r > 0 ? r + 0.5f : 0)) using (var b = new SolidBrush(BackColor)) g.FillPath(b, p);
  if (!string.IsNullOrEmpty(Border)) using (var p = MxTheme.Round(MxTheme.Edge(0, 0, Width, Height, 1), r)) using (var pen = new Pen(MxTheme.C(Border), 1)) g.DrawPath(pen, p);
  if (TopRule) { g.SmoothingMode = SmoothingMode.None; using (var pen = new Pen(MxTheme.C("Rule"), 1)) g.DrawLine(pen, 0, 0, Width, 0); }
 }
}
// State chip: recording, live lock, saved or temporary. The glyph carries the meaning as well as the tint.
public class MxChip : Control {
 public string Glyph = "", Tone = "neutral"; public bool GlyphOff;
 public MxChip() { SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.ResizeRedraw | ControlStyles.SupportsTransparentBackColor, true); TabStop = false; AccessibleRole = AccessibleRole.StaticText; }
 protected override void OnTextChanged(EventArgs e) { base.OnTextChanged(e); AccessibleName = Text; Invalidate(); }
 public override Size GetPreferredSize(Size proposed) {
  using (var g = MxTheme.Measure()) {
   float s = g.DpiX / 96f, w = MxTheme.Width(g, Text, Font);
   return new Size((int)Math.Ceiling(26 * s + w + 10 * s), (int)Math.Ceiling(Math.Max(22 * s, Font.GetHeight(g) + 8 * s)));
  }
 }
 protected override void OnPaint(PaintEventArgs e) {
  var g = e.Graphics; float s = MxTheme.S(g);
  g.Clear(Parent != null ? Parent.BackColor : MxTheme.C("Surface"));
  g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = MxTheme.Hint;
  string tint = Tone == "rec" ? "RecTint" : Tone == "lamp" ? "LampTint" : "Background";
  Color mark = MxTheme.C(Tone == "rec" ? "Rec" : Tone == "lamp" ? "Lamp" : Tone == "success" ? "Success" : "Muted");
  using (var p = MxTheme.Round(MxTheme.Cover(0, 0, Width, Height), Height / 2f)) using (var b = new SolidBrush(MxTheme.C(tint))) g.FillPath(b, p);
  float gs = MxTheme.Snap(12 * s), gx = MxTheme.Snap(8 * s), gy = (float)Math.Floor((Height - gs) / 2);
  if (Glyph == "record") {
   float d = gs - MxTheme.Snap(4 * s), dx = gx + (gs - d) / 2, dy = gy + (gs - d) / 2;
   if (GlyphOff) { int lp = MxTheme.Px(1.3f * s); using (var pen = new Pen(mark, lp)) g.DrawEllipse(pen, MxTheme.Edge(dx, dy, d, d, lp)); }
   else using (var b = new SolidBrush(mark)) g.FillEllipse(b, MxTheme.Cover(dx, dy, d, d));
  } else MxIcons.Draw(g, Glyph, new RectangleF(gx, gy, gs, gs), mark);
  float tx = MxTheme.Snap(26 * s);
  MxTheme.Text(g, Text, Font, MxTheme.C("Text"), new RectangleF(tx, 0, Width - tx - 4 * s, Height), StringAlignment.Near);
 }
}
// The comparison track: 1 · 2 · 1 as lens discs, the current one filled, and the time left as a draining line.
public class MxLensTrack : Control {
 public string[] Numbers = new string[0], Labels = new string[0];
 public int Active = -1, Emphasis = -1; public float Remaining = -1; public string TimeText = "";
 public Font NumberFont, CaptionFont;
 public MxLensTrack() { SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true); TabStop = false; AccessibleRole = AccessibleRole.StaticText; }
 Font Cap { get { return CaptionFont ?? Font; } }
 public override Size GetPreferredSize(Size proposed) {
  using (var g = MxTheme.Measure()) {
   float s = g.DpiX / 96f, h = 0, ch = Cap.GetHeight(g);
   if (Numbers.Length > 0) h += 30 * s + 6 * s + ch;
   if (Remaining >= 0) h += (h > 0 ? 14 * s : 0) + 4 * s + 6 * s + ch;
   return new Size(proposed.Width > 1 && proposed.Width < 100000 ? proposed.Width : Width, (int)Math.Ceiling(h + 2 * s));
  }
 }
 protected override void OnPaint(PaintEventArgs e) {
  var g = e.Graphics; float s = MxTheme.S(g), y = 0, ch = Cap.GetHeight(g);
  g.Clear(Parent != null ? Parent.BackColor : MxTheme.C("Background"));
  g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = MxTheme.Hint;
  int n = Numbers.Length;
  if (n > 0) {
   float slot = Width / (float)n, d = MxTheme.Snap(30 * s); int lp = MxTheme.Px(1.5f * s); float ly = MxTheme.Snap(d / 2) + (lp % 2 == 0 ? 0.5f : 0);
   for (int i = 0; i < n - 1; i++) {
    float x1 = MxTheme.Snap(slot * i + slot / 2 + d / 2 + 6 * s), x2 = MxTheme.Snap(slot * (i + 1) + slot / 2 - d / 2 - 6 * s);
    using (var pen = new Pen(MxTheme.C(Active > i ? "Text" : "Rule"), lp)) g.DrawLine(pen, x1, ly, x2, ly);
   }
   for (int i = 0; i < n; i++) {
    float cx = MxTheme.Snap(slot * i + slot / 2 - d / 2);
    bool lit = i == Active || i == Emphasis, done = Active >= 0 && i < Active;
    int dp = MxTheme.Px((done ? 1.6f : 1.2f) * s);
    using (var b = new SolidBrush(MxTheme.C(lit ? "Ink" : "Surface"))) g.FillEllipse(b, MxTheme.Cover(cx, 0, d, d));
    using (var pen = new Pen(MxTheme.C(lit ? "Ink" : done ? "Text" : "Field"), dp)) g.DrawEllipse(pen, MxTheme.Edge(cx, 0, d, d, dp));
    MxTheme.Text(g, i < Numbers.Length ? Numbers[i] : "", NumberFont ?? Font, MxTheme.C(lit ? "OnInk" : done ? "Text" : "Muted"), new RectangleF(cx, 0, d, d), StringAlignment.Center);
    MxTheme.Text(g, i < Labels.Length ? Labels[i] : "", Cap, MxTheme.C(lit ? "Text" : "Muted"), new RectangleF(slot * i + 2 * s, d + MxTheme.Snap(6 * s), slot - 4 * s, ch), StringAlignment.Center);
   }
   y = d + MxTheme.Snap(6 * s) + ch;
  }
  if (Remaining >= 0) {
   if (n > 0) y += 14 * s;
   y = MxTheme.Snap(y); float bh = MxTheme.Snap(4 * s);
   using (var p = MxTheme.Round(MxTheme.Cover(0, y, Width, bh), bh / 2)) using (var b = new SolidBrush(MxTheme.C("Rule"))) g.FillPath(b, p);
   float lw = MxTheme.Snap(Math.Max(bh, Width * Math.Min(1, Remaining)));
   using (var p = MxTheme.Round(MxTheme.Cover(0, y, lw, bh), bh / 2)) using (var b = new SolidBrush(MxTheme.C("Ink"))) g.FillPath(b, p);
   MxTheme.Text(g, TimeText, Cap, MxTheme.C("Muted"), new RectangleF(0, y + bh + MxTheme.Snap(6 * s), Width, ch), StringAlignment.Near);
  }
 }
}
'@
}
function Set-UiNativeTheme ($Control, [string]$Class='DarkMode_Explorer') {
  # Dark scrollbars and list chrome come from the system dark theme class; light and high contrast use the default.
  if ((Get-UiTheme) -eq 'dark') {
    $Control | Add-Member -NotePropertyName MxThemeClass -NotePropertyValue $Class -Force
    $Control.Add_HandleCreated({ try { [void][MirrodexDwm]::SetWindowTheme($this.Handle,$this.MxThemeClass,$null) } catch {} })
  }
}
# Hands the token colors to the drawn controls; re-applied if the theme is switched (tests render both).
function Initialize-UiTheme {
  Initialize-UiNative
  if ($script:UiThemeApplied -eq (Get-UiTheme)) { return }
  foreach ($name in $script:UiPalette[(Get-UiTheme)].Keys) { [MxTheme]::Set($name,(Get-UiColor $name)) }
  [MxTheme]::Motion=[MirrodexDwm]::Animations()
  # Text like native Windows apps: ClearType with hinting when Windows uses ClearType, grayscale otherwise.
  $clearType=[Windows.Forms.SystemInformation]::IsFontSmoothingEnabled -and [Windows.Forms.SystemInformation]::FontSmoothingType -eq 2
  [MxTheme]::Hint=if ($clearType) { [Drawing.Text.TextRenderingHint]::ClearTypeGridFit } else { [Drawing.Text.TextRenderingHint]::AntiAlias }
  $script:UiThemeApplied=Get-UiTheme
}

# ---- Components --------------------------------------------------------------------------------------
# Variants: primary (the one expected next step), secondary, danger, choice / choice-primary (answers in the assistant),
# row (side menu), quiet (other options), key (quick action), compact, link. Text is Korean source, translated at display.
function New-UiButton ([string]$Text, [string]$Key='', [string]$Variant='secondary', [string]$Icon='', [string]$Trail='', [switch]$Reconnects) {
  $button=New-Object MxButton
  Set-UiText $button $Text; $button.Tag=$Key
  $button.Variant=$Variant; $button.Icon=$Icon; $button.Trail=$Trail; $button.Reconnects=[bool]$Reconnects
  $detail=$Text.Contains(' · ')
  Set-UiFont $button $(switch ($Variant) { 'compact' {'Caption'} 'link' {'Caption'} 'row' {'Body'} 'quiet' {'Body'} default {'Label'} })
  Set-UiFont $button 'Caption' 'DetailFont'
  $button.Height=switch ($Variant) {
    'compact' { $script:UiSpace.Compact } 'link' { $script:UiSpace.Link } 'key' { $script:UiSpace.Key }
    'row' { if ($detail) { $script:UiSpace.RowDetail } else { $script:UiSpace.Row } }
    { $_ -like 'choice*' } { if ($detail) { $script:UiSpace.ChoiceDetail } else { $script:UiSpace.Choice } }
    'quiet' { if ($detail) { $script:UiSpace.QuietDetail } else { $script:UiSpace.Quiet } }
    default { $script:UiSpace.Button }
  }
  $button.MinimumSize=New-Object Drawing.Size(0,$button.Height)
  $button.Margin=New-UiPadding 0 0 0 $script:UiSpace.Gap
  if ($Variant -in @('compact','link')) { $button.AutoSize=$true; $button.AutoSizeMode='GrowAndShrink' }
  return $button
}
function Set-UiButtonStyle ($Button, [string]$Variant, [string]$Icon, [string]$Trail) {
  $Button.Variant=$Variant; $Button.Icon=$Icon; $Button.Trail=$Trail; $Button.Invalidate()
}
function New-UiToggle ([string]$Text, [bool]$Checked, [string]$Icon) {
  $toggle=New-Object MxToggle
  Set-UiText $toggle $Text; $toggle.Icon=$Icon; $toggle.Checked=$Checked
  Set-UiFont $toggle 'Label'; Set-UiFont $toggle 'Caption' 'DetailFont'
  $toggle.Height=$script:UiSpace.Key; $toggle.MinimumSize=New-Object Drawing.Size(0,$toggle.Height)
  return $toggle
}
# Text roles: title (one per dialog), headline, body, muted, caption, section (group name).
function New-UiText ([string]$Text, [string]$Role='body', [int]$MaxWidth=0) {
  $label=New-Object MirrodexLabel; $label.AutoSize=$true
  if ($MaxWidth) { $label.MaximumSize=New-Object Drawing.Size($MaxWidth,0) }
  $label.ForeColor=Get-UiColor 'Text'
  switch ($Role) {
    'title' { Set-UiFont $label 'Title'; $label.Margin=New-UiPadding 0 0 0 $script:UiSpace.Title }
    'headline' { Set-UiFont $label 'Headline'; $label.Margin=New-UiPadding 0 0 0 2 }
    'muted' { Set-UiFont $label 'Body'; $label.ForeColor=Get-UiColor 'Muted'; $label.Margin=New-UiPadding 0 0 0 $script:UiSpace.Body }
    'caption' { Set-UiFont $label 'Caption'; $label.ForeColor=Get-UiColor 'Muted'; $label.Margin=New-UiPadding 0 $script:UiSpace.Gap 0 0 }
    'section' { Set-UiFont $label 'Section'; $label.ForeColor=Get-UiColor 'Muted'; $label.Margin=New-UiPadding 0 $script:UiSpace.Section 0 $script:UiSpace.Gap }
    default { Set-UiFont $label 'Body'; $label.Margin=New-UiPadding 0 0 0 $script:UiSpace.Body }
  }
  Set-UiText $label $Text
  return $label
}
# Message tones: info, success, danger (errors), busy (work in progress), rec (recording). Each has its own glyph,
# so the tone reads without color. A file path makes the "open file location" link appear next to the message.
function Set-UiStatus ($Label, [string]$Text, [string]$Tone='info', [string]$Path='') {
  # The glyph carries the tone; only errors color the text itself, so paths stay readable.
  $color=switch ($Tone) { 'success' {'Success'} 'danger' {'Danger'} 'rec' {'Rec'} 'busy' {'Text'} default {'Muted'} }
  $Label.GlyphColor=Get-UiColor $color
  $Label.ForeColor=Get-UiColor $(switch ($Tone) { 'danger' {'Danger'} 'info' {'Muted'} default {'Text'} })
  $Label.Glyph=switch ($Tone) { 'success' {'check'} 'danger' {'alert'} 'busy' {'clock'} 'rec' {'record'} default {'info'} }
  Set-UiText $Label $Text
  $visible=[bool]$Text; $changed=($Label.Visible -ne $visible)
  $Label.Visible=$visible
  if ($Label.PSObject.Properties['MxOpen']) {
    $Label | Add-Member -NotePropertyName MxPath -NotePropertyValue $Path -Force
    if ($Label.MxOpen.Visible -ne [bool]$Path) { $changed=$true }
    $Label.MxOpen.Visible=[bool]$Path
  }
  $Label.Invalidate()
  $form=$Label.FindForm()
  if ($changed -and $form -and $form.PSObject.Properties['MxSidebar'] -and $form.Visible) { Fit-Sidebar $form }
}
function New-UiCheck ([string]$Text, [bool]$Checked=$false) {
  $check=New-Object MirrodexCheckBox
  Set-UiFont $check 'Body'; $check.ForeColor=Get-UiColor 'Text'; $check.Cursor=[Windows.Forms.Cursors]::Hand
  $check.Checked=$Checked; $check.Margin=New-UiPadding 0 2 0 $script:UiSpace.Gap
  Set-UiText $check $Text
  return $check
}
function New-UiCombo ($Items, $Selected, [string]$Name) {
  $combo=New-Object MirrodexComboBox; $combo.Dock='Top'
  Set-UiFont $combo 'Body'
  $combo.BackColor=Get-UiColor 'Surface'; $combo.ForeColor=Get-UiColor 'Text'; $combo.Cursor=[Windows.Forms.Cursors]::Hand
  $combo.FormattingEnabled=$true; $combo.Add_Format({ $_.Value=T ([string]$_.ListItem) })
  foreach ($item in $Items) { [void]$combo.Items.Add($item) }
  $combo.SelectedItem=$Selected; $combo.AccessibleName=T $Name
  Set-UiNativeTheme $combo 'DarkMode_CFD'
  return $combo
}
# Single-line input in a rounded field with a 3:1 boundary; the border thickens in the focus color while typing.
function New-UiInput ([string]$Value='', [string]$Placeholder='', [string]$Name='') {
  $frame=New-Object Windows.Forms.Panel
  $frame.Height=$script:UiSpace.Button; $frame.Dock='Top'; $frame.Margin=New-UiPadding 0 0 0 $script:UiSpace.Gap
  $frame.Padding=New-UiPadding 11 9 11 7; $frame.BackColor=Get-UiColor 'Surface'
  $box=New-Object Windows.Forms.TextBox
  $box.BorderStyle='None'; $box.Dock='Fill'; Set-UiFont $box 'Body'
  $box.BackColor=Get-UiColor 'Surface'; $box.ForeColor=Get-UiColor 'Text'; $box.Text=$Value; $box.AccessibleName=T $Name
  if ($Placeholder) { $box.Add_HandleCreated({ [void][MirrodexDwm]::SendMessage($this.Handle,0x1501,[IntPtr]1,(T $this.Tag)) }); $box.Tag=$Placeholder }
  $frame.Controls.Add($box)
  $frame.Add_Paint({
    $g=$_.Graphics; $g.SmoothingMode='AntiAlias'; $scale=$g.DpiX/96
    $g.Clear($this.Parent.BackColor)
    $focused=$this.Controls[0].Focused; $width=if ($focused) { [MxTheme]::Px(2*$scale) } else { 1 }
    # Whole-pixel outline (see MxTheme): a border on x.5 would smear into two gray pixels.
    $area=[MxTheme]::Round([MxTheme]::Cover(0,0,$this.Width,$this.Height),(6*$scale+0.5))
    $path=[MxTheme]::Round([MxTheme]::Edge(0,0,$this.Width,$this.Height,$width),(6*$scale))
    $fill=New-Object Drawing.SolidBrush(Get-UiColor 'Surface'); $pen=New-Object Drawing.Pen((Get-UiColor $(if ($focused) {'Focus'} else {'Field'})),$width)
    try { $g.FillPath($fill,$area); $g.DrawPath($pen,$path) } finally { $fill.Dispose(); $pen.Dispose(); $path.Dispose(); $area.Dispose() }
  })
  $box.Add_GotFocus({ $this.Parent.Invalidate() }); $box.Add_LostFocus({ $this.Parent.Invalidate() })
  $frame | Add-Member -NotePropertyName Input -NotePropertyValue $box
  return $frame
}
function New-UiList ($Items) {
  $list=New-Object MirrodexListBox
  Set-UiFont $list 'Body'; Set-UiFont $list 'Caption' 'DetailFont'
  $list.BackColor=Get-UiColor 'Surface'; $list.ForeColor=Get-UiColor 'Text'
  $list.Dock='Fill'; $list.Margin=New-UiPadding 0 0 0 0
  foreach ($item in $Items) { [void]$list.Items.Add($item) }
  Set-UiNativeTheme $list
  return $list
}
# A rounded surface (Now card, ruled groups). Padding is the inner inset; children stack top to bottom.
function New-UiCard ([int]$Inset=$script:UiSpace.Inset) {
  $card=New-Object MxCard
  $card.ColumnCount=1; $card.AutoSize=$true; $card.AutoSizeMode='GrowAndShrink'; $card.Dock='Top'
  [void]$card.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',100)))
  $card.BackColor=Get-UiColor 'Surface'; $card.Padding=New-UiPadding $Inset $Inset $Inset $Inset
  $card.Margin=New-UiPadding 0 0 0 $script:UiSpace.Group
  return $card
}
function New-UiChip ([string]$Text, [string]$Glyph, [string]$Tone='neutral') {
  $chip=New-Object MxChip
  Set-UiFont $chip 'Caption'; $chip.Glyph=$Glyph; $chip.Tone=$Tone; $chip.AutoSize=$true
  $chip.Margin=New-UiPadding 0 0 6 4
  Set-UiText $chip $Text
  return $chip
}
# 1 · 2 · 1: the comparison as lens discs. Labels are Korean source, translated at display and on language switch.
function New-UiLensTrack ([int]$Active=-1, [int]$Emphasis=-1, [switch]$Timer, [switch]$NoDiscs) {
  $track=New-Object MxLensTrack
  Set-UiFont $track 'Caption'; Set-UiFont $track 'Numeral' 'NumberFont'; Set-UiFont $track 'Caption' 'CaptionFont'
  if (-not $NoDiscs) {
    $track.Numbers=[string[]]@('1','2','1')
    $track | Add-Member -NotePropertyName MxLabels -NotePropertyValue @('현재 화면','바꿔 본 화면','현재 화면 다시 보기')
    $track.Labels=[string[]]@($track.MxLabels | ForEach-Object { T $_ })
  }
  $track.Active=$Active; $track.Emphasis=$Emphasis; if ($Timer) { $track.Remaining=1 }
  # AutoSize: measured after DPI scaling, like text.
  $track.AutoSize=$true; $track.Dock='Top'; $track.Margin=New-UiPadding 0 4 0 $script:UiSpace.Body
  return $track
}
# Slow actions show one consistent busy state: wait cursor, disabled trigger, clock message, then the result.
function Invoke-UiBusy ($Button, $Status, [string]$Message, [scriptblock]$Action) {
  $form=$Button.FindForm(); $Button.Enabled=$false; $form.UseWaitCursor=$true
  if ($Status) { Set-UiStatus $Status $Message 'busy' }
  [Windows.Forms.Application]::DoEvents()
  try { & $Action } finally { $form.UseWaitCursor=$false; $Button.Enabled=$true }
}

# ---- Window chrome -----------------------------------------------------------------------------------
function Set-ModernForm ($Form) {
  Initialize-UiTheme
  # Designer order inside a suspended layout: sizes set while building are in 96-DPI units and scale once on
  # resume. Outside a suspension the form scales immediately while empty and later sizes stay unscaled.
  # Every builder calls Complete-UiForm when done.
  $Form.SuspendLayout()
  $Form.AutoScaleDimensions=New-Object Drawing.SizeF(96,96); $Form.AutoScaleMode='Dpi'
  $Form.BackColor=Get-UiColor 'Background'
  $Form.ForeColor=Get-UiColor 'Text'
  Set-UiFont $Form 'Body'
  $iconPath=Join-Path $PSScriptRoot 'mirrodex.ico'
  if (Test-Path -LiteralPath $iconPath) { $Form.Icon=New-Object Drawing.Icon($iconPath); $Form.Add_Disposed({ if ($this.Icon) { $this.Icon.Dispose() } }) }
  # Windows 11: title bar matches the theme and window background, corners are rounded. Older Windows ignores this.
  $Form.Add_HandleCreated({
    try {
      $round=2; [void][MirrodexDwm]::DwmSetWindowAttribute($this.Handle,33,[ref]$round,4)
      if ((Get-UiTheme) -eq 'contrast') { return }
      $bg=Get-UiColor 'Background'; $caption=[int]$bg.R -bor ([int]$bg.G -shl 8) -bor ([int]$bg.B -shl 16)
      $dark=[int]((Get-UiTheme) -eq 'dark'); $fg=Get-UiColor 'Text'; $text=[int]$fg.R -bor ([int]$fg.G -shl 8) -bor ([int]$fg.B -shl 16)
      [void][MirrodexDwm]::DwmSetWindowAttribute($this.Handle,20,[ref]$dark,4)
      [void][MirrodexDwm]::DwmSetWindowAttribute($this.Handle,35,[ref]$caption,4)
      [void][MirrodexDwm]::DwmSetWindowAttribute($this.Handle,36,[ref]$text,4)
    } catch {}
  })
}
function Complete-UiForm ($Form) { $Form.ResumeLayout($false) }
# A scroll panel holds a top-docked table sized to its content, so the scroll range is exact (a scrolling table
# stretches its last row to a stale height). The panel is a child window: it takes the dark scrollbar theme,
# which on the form itself would drop the Windows 11 title bar. $Form.MxLayout is the table.
function New-UiLayout ($Form, [int]$Padding=$script:UiSpace.Window) {
  $scroll=New-Object Windows.Forms.Panel
  $scroll.Dock='Fill'; $scroll.AutoScroll=$true
  Set-UiNativeTheme $scroll
  $layout=New-Object Windows.Forms.TableLayoutPanel
  $layout.Dock='Top'; $layout.ColumnCount=1; $layout.AutoSize=$true; $layout.AutoSizeMode='GrowAndShrink'
  $layout.Padding=New-UiPadding $Padding $Padding $Padding $Padding
  [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',100)))
  $scroll.Controls.Add($layout); $Form.Controls.Add($scroll)
  $Form | Add-Member -NotePropertyName MxLayout -NotePropertyValue $layout -Force
  return $layout
}
function Add-BrandHeader ($Layout, $Caption='Mirrodex') {
  $row=New-Object Windows.Forms.TableLayoutPanel
  $row.AutoSize=$true; $row.Dock='Fill'; $row.ColumnCount=3; $row.RowCount=1; $row.Margin=New-UiPadding 0 0 0 $script:UiSpace.Header
  [void]$row.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('AutoSize')))
  [void]$row.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',100)))
  [void]$row.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('AutoSize')))
  $picture=New-UiLogo 26
  if ($picture) {
    # Easter egg: five quick clicks on the logo open the creator card.
    $picture.Add_Click({ Register-LogoClick $this })
    $picture.Anchor='Left'
    $row.Controls.Add($picture,0,0)
  }
  $label=New-Object MirrodexLabel
  $label.Text=$Caption; $label.AutoSize=$true; Set-UiFont $label 'Brand'; $label.Anchor='Left'; $label.ForeColor=Get-UiColor 'Text'
  $label.Margin=New-UiPadding $script:UiSpace.Gap 0 0 0
  $row.Controls.Add($label,1,0)
  # Language switch: re-labels the open window in place, so a running mirror session is never interrupted.
  $toggle=New-UiButton '' 'language' 'compact'
  $toggle.Text=Get-LanguageToggleText; $toggle.AccessibleName='Language / 언어'; $toggle.Anchor='Right'
  $toggle.Margin=New-UiPadding 0 0 0 0
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
# For a short visible label (e.g. 'Change'), the screen-reader name spells out the whole action; it follows the language too.
function Set-UiAccessibleName ($Control, [string]$Text) {
  $Control | Add-Member -NotePropertyName MxAccessible -NotePropertyValue $Text -Force
  $Control.AccessibleName=T $Text
}
function Update-UiLanguage ($Form) {
  $stack=New-Object Collections.Stack; $stack.Push($Form)
  while ($stack.Count) {
    $control=$stack.Pop()
    if ($control.PSObject.Properties['MxFonts']) { foreach ($entry in @($control.MxFonts.GetEnumerator())) { $control.($entry.Key)=New-UiFont $entry.Value } }
    if ($control.PSObject.Properties['MxSource']) { $control.Text=T $control.MxSource }
    if ($control.PSObject.Properties['MxAccessible']) { $control.AccessibleName=T $control.MxAccessible }
    if ($control.PSObject.Properties['MxLanguageToggle']) { $control.Text=Get-LanguageToggleText }
    if ($control.PSObject.Properties['MxLabels']) { $control.Labels=[string[]]@($control.MxLabels | ForEach-Object { T $_ }) }
    $control.Invalidate()
    foreach ($child in $control.Controls) { $stack.Push($child) }
  }
  if ($Form.PSObject.Properties['MxGuide']) { Fit-GuideContent $Form }
  if ($Form.PSObject.Properties['MxSidebar']) { Fit-Sidebar $Form }
}

# ---- Side menu ---------------------------------------------------------------------------------------
# Top to bottom: header; Now (what is shown, how, and whether it records, is locked or saved); four keys; screen
# (assistant, folded engine settings); connection; help links and the reconnect legend.
function Get-SourceLabel ($Source) {
  switch ($Source.Kind) {
    'app' { return "앱 하나만 · $($Source.Label)" }
    'camera' { if ($Source.Facing -eq 'front') { return '전면 카메라' } else { return '후면 카메라' } }
    default { return '휴대폰 화면 전체' }
  }
}
function Get-SourceIcon ($Source) { switch ($Source.Kind) { 'app' {'app'} 'camera' {'camera'} default {'screen'} } }
# The settings every "saved / not saved" comparison looks at (serial and legacy arr are left out).
$script:UiConfigKeys=@('codec','encoder','size','rate','buffer','fps','audio','audiobuffer','requireaudio')
function Test-ConfigSaved ($Config) {
  try { if (-not (Test-Path -LiteralPath $Cfg)) { return $false }; $saved=Import-Config $Cfg } catch { return $false }
  return -not @($script:UiConfigKeys | Where-Object { [string]$saved[$_] -ne [string]$Config[$_] }).Count
}
function New-Sidebar ($Config, $Device) {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $form=New-Object Windows.Forms.Form
  Set-UiText $form 'Mirrodex 설정 · 방송에 공유하지 않는 창'
  $form | Add-Member -NotePropertyName MxSidebar -NotePropertyValue $true
  $form.StartPosition='Manual'; $form.MaximizeBox=$false
  Set-ModernForm $form
  $form.ClientSize=New-Object Drawing.Size(380,600)
  $form.MinimumSize=New-Object Drawing.Size(360,300)
  $form.TopMost=[bool]$script:AlwaysOnTop
  $layout=New-UiLayout $form $script:UiSpace.Panel
  Add-BrandHeader $layout
  $width=380-2*$script:UiSpace.Panel-2
  $inner=$width-2*$script:UiSpace.Inset
  $state=@{Config=$Config.Clone(); Device=$Device; Request=$null; Ready=$false; Dock=$true}

  # Now: the source is the headline; its Change action sits beside it, so state and action are read together.
  $now=New-UiCard
  $head=New-Object Windows.Forms.TableLayoutPanel
  $head.ColumnCount=2; $head.RowCount=1; $head.AutoSize=$true; $head.Dock='Top'; $head.Margin=New-UiPadding 0 0 0 0
  [void]$head.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',100)))
  [void]$head.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('AutoSize')))
  $headline=New-UiText (Get-SourceLabel $script:Source) 'headline' ($inner-84)
  $headline.Glyph=Get-SourceIcon $script:Source; $headline.Anchor='Left'
  $head.Controls.Add($headline,0,0)
  $state.Source=New-UiButton '바꾸기' 'source' 'compact' -Reconnects
  Set-UiAccessibleName $state.Source '보여줄 화면 바꾸기'; $state.Source.Anchor='Right'; $state.Source.Margin=New-UiPadding 8 0 0 0
  $state.Source.Add_Click({ Invoke-SidebarAction $this })
  $head.Controls.Add($state.Source,1,0)
  $now.Controls.Add($head)
  $codec=if ($Config.codec -eq 'h265') {'H.265'} else {'H.264'}
  $readout=New-UiText "$($Config.size)px · 최대 $($Config.fps)fps · $($Config.rate) · $codec" 'caption' $inner
  $readout.Padding=New-UiPadding $script:UiSpace.Indent 0 0 0; $readout.Margin=New-UiPadding 0 0 0 0
  $now.Controls.Add($readout)
  $transport=if (Test-WirelessSerial $Config.serial) {'무선 연결'} else {'케이블 연결'}
  $model=if ($Device -and $Device.Model) { ([string]$Device.Model).Trim() } else { '' }
  $deviceLine=New-UiText $(if ($model) { "$model · $transport" } else { $transport }) 'caption' $inner
  $deviceLine.Padding=New-UiPadding $script:UiSpace.Indent 0 0 0; $deviceLine.Margin=New-UiPadding 0 0 0 $script:UiSpace.Gap
  $now.Controls.Add($deviceLine)
  $chips=New-Object Windows.Forms.FlowLayoutPanel
  $chips.AutoSize=$true; $chips.Dock='Top'; $chips.WrapContents=$true; $chips.Margin=New-UiPadding 0 0 0 0
  $chips.Padding=New-UiPadding $script:UiSpace.Indent 0 0 0
  $state.RecChip=New-UiChip '녹화 중 00:00' 'record' 'rec'; $state.RecChip.Visible=[bool]$script:Recording
  $state.LockChip=New-UiChip '재연결 잠금' 'lock' 'lamp'; $state.LockChip.Visible=$false
  $state.SavedChip=New-UiChip '' 'check'
  foreach ($chip in @($state.RecChip,$state.LockChip,$state.SavedChip)) { $chips.Controls.Add($chip) }
  $now.Controls.Add($chips)
  $status=New-UiText '' 'body' $inner; $status.Margin=New-UiPadding 0 $script:UiSpace.Gap 0 0; $status.Visible=$false
  $now.Controls.Add($status); $state.Status=$status
  $open=New-UiButton '파일 위치 열기' 'open' 'link' 'folder'
  $open.Margin=New-UiPadding ($script:UiSpace.Indent-3) 2 0 0; $open.Visible=$false
  $open.Add_Click({ Invoke-SidebarAction $this })
  $now.Controls.Add($open)
  $status | Add-Member -NotePropertyName MxOpen -NotePropertyValue $open
  $layout.Controls.Add($now)
  Set-SidebarSaved $state (Test-ConfigSaved $Config)
  if ($script:Recording) {
    $text="녹화 중입니다. 중지하면 파일이 저장됩니다.`n$script:RecordFile"
    if ($Config.audio -eq 'off') { $text+="`n소리가 휴대폰에서 재생되므로 녹화에는 포함되지 않습니다." }
    Set-UiStatus $status $text 'rec'
  } elseif ($script:Notice) { Set-UiStatus $status $script:Notice.Text $script:Notice.Tone; $script:Notice=$null }
  elseif ($script:LastRecording) { Set-UiStatus $status "녹화 파일을 저장했습니다.`n$script:LastRecording" 'success' $script:LastRecording }

  # Keys: toggles carry a lamp (filled when on); instant actions have none. The reconnect glyph marks interruptions.
  $keys=New-Object Windows.Forms.TableLayoutPanel
  $keys.ColumnCount=2; $keys.RowCount=2; $keys.AutoSize=$true; $keys.Dock='Top'; $keys.Margin=New-UiPadding 0 0 0 $script:UiSpace.Group
  foreach ($i in 1..2) { [void]$keys.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',50))) }
  $state.Record=New-UiButton $(if ($script:Recording) {'녹화 중지 · 파일 저장'} else {'화면 녹화 시작 · 동영상 폴더'}) 'record' 'key' $(if ($script:Recording) {'stop'} else {'record'}) -Reconnects
  $state.Record.Lamp=if ($script:Recording) { 2 } else { 0 }
  $state.Screenshot=New-UiButton '스크린샷 저장 · 사진 폴더' 'screenshot' 'key' 'camera'
  $state.OnTop=New-UiToggle '항상 위에 표시 · 미러링 창' ([bool]$script:AlwaysOnTop) 'pin'
  Set-UiAccessibleName $state.OnTop '미러링 창을 항상 위에 표시'
  $state.OnTop.Add_CheckedChanged({ Set-AlwaysOnTop $this.Checked; $this.FindForm().TopMost=$this.Checked })
  $state.Lock=New-UiToggle '방송 중 · 재연결 잠금' $false 'lock'
  $cells=@(@($state.Record,0,0),@($state.Screenshot,1,0),@($state.OnTop,0,1),@($state.Lock,1,1))
  foreach ($cell in $cells) {
    $key=$cell[0]; $key.Dock='Fill'
    $key.Margin=New-UiPadding $(if ($cell[1]) {4} else {0}) 0 $(if ($cell[1]) {0} else {4}) $(if ($cell[2]) {0} else {$script:UiSpace.Gap})
    if ($key -is [MxButton]) { $key.Add_Click({ Invoke-SidebarAction $this }) }
    $keys.Controls.Add($key,$cell[1],$cell[2])
  }
  $layout.Controls.Add($keys)

  # Screen: the assistant first (the guided path), then the folded engine settings for people who know them.
  $layout.Controls.Add((New-UiText '화면' 'section'))
  $screen=New-UiCard 0
  $state.Guide=Add-SidebarRow $screen '도우미로 화면 맞추기 · 불편한 점을 한 가지씩 비교합니다' 'guide' 'lens' 'chevron-right' -Reconnects
  $state.Expand=Add-SidebarRow $screen (Get-SidebarExpandText) 'expand' 'sliders' $(if ($script:SidebarExpanded) {'chevron-up'} else {'chevron-down'})
  $state.Expand.Divider=$true
  $settings=New-Object Windows.Forms.TableLayoutPanel
  $settings.ColumnCount=1; $settings.AutoSize=$true; $settings.Dock='Top'
  $settings.Margin=New-UiPadding 0 0 0 0; $settings.Padding=New-UiPadding $script:UiSpace.Inset 0 $script:UiSpace.Inset $script:UiSpace.Inset
  [void]$settings.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',100)))
  $settings.Visible=[bool]$script:SidebarExpanded
  $screen.Controls.Add($settings); $state.Settings=$settings
  $fields=@{}; $initial=@{}
  $specs=@(
    @('size','화면 선명도 · 긴 변 px',@(800,1024,1280,1600,1920,2340,$Device.Long)),
    @('fps','프레임 상한 · fps',@(30,60)),
    @('rate','화질 · 전송량',@('4M','6M','8M','12M','16M','20M')),
    @('buffer','영상 완충 · ms',@(0,16,33,50,80,100,150,200)),
    @('audiobuffer','소리 완충 · ms',@(30,50,80,100,150,200)),
    @('codec','화면 압축 방식',@('h264','h265')),
    @('audio','소리가 나올 곳',@('output','off')))
  foreach ($spec in $specs) {
    # A ruled record line: name left, value right. A dashed underline marks a value chosen but not applied yet.
    $row=New-Object MxCard; $row.Border=''; $row.Radius=0; $row.TopRule=$true; $row.BackColor=Get-UiColor 'Surface'
    $row.ColumnCount=2; $row.AutoSize=$true; $row.Dock='Top'; $row.Margin=New-UiPadding 0 0 0 0; $row.Padding=New-UiPadding 0 6 0 6
    [void]$row.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',100)))
    [void]$row.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Absolute',$script:UiSpace.Field)))
    $label=New-UiText $spec[1] 'body'; $label.Anchor='Left'; $label.Margin=New-UiPadding 0 0 8 0
    $current=[string]$Config[$spec[0]]
    if (-not $current) { $current=if ($spec[0] -eq 'audio') {'output'} elseif ($spec[0] -eq 'audiobuffer') {'50'} else {''} }
    $values=@($spec[2])+@($current)
    if ($spec[0] -eq 'size') { $values=@($values | Where-Object { [int]$_ -le $Device.Long }) }
    if ($spec[0] -eq 'codec') { $values=@($values | Where-Object { $_ -eq $Config.codec -or (Get-Encoder $Device.Encoders $_) }) }
    $items=@($values | Select-Object -Unique | ForEach-Object { if ($spec[0] -eq 'audio') { if ($_ -eq 'output') {'노트북'} else {'휴대폰'} } else {[string]$_} })
    $selected=if ($spec[0] -eq 'audio') { if ($current -eq 'output') {'노트북'} else {'휴대폰'} } else {$current}
    $combo=New-UiCombo $items $selected $spec[1]
    $combo.Margin=New-UiPadding 0 0 0 0
    $combo.Add_SelectedIndexChanged({ $s=$this.FindForm().Tag; if ($s) { Update-SidebarDraft $s } })
    $fields[$spec[0]]=$combo; $initial[$spec[0]]=[string]$selected
    $row.Controls.Add($label,0,0); $row.Controls.Add($combo,1,0); $settings.Controls.Add($row)
  }
  $state.Fields=$fields; $state.Initial=$initial
  $state.Required=New-UiCheck '방송용 · 소리 연결 실패 시 알려주기' ($Config.requireaudio -eq '1')
  $state.Required.Margin=New-UiPadding 0 6 0 0
  $state.Required.Add_CheckedChanged({ $s=$this.FindForm().Tag; if ($s) { Update-SidebarDraft $s } })
  $settings.Controls.Add($state.Required)
  $state.Draft=New-UiText '' 'body' $inner; $state.Draft.Margin=New-UiPadding 0 $script:UiSpace.Gap 0 2
  $settings.Controls.Add($state.Draft)
  $note=New-UiText "적용하면 화면과 소리가 잠시 다시 연결되며 이번 실행에만 쓰입니다. 계속 쓰려면 저장하십시오.`nDiscord에서 공유 창을 다시 선택해야 할 수 있습니다." 'caption' $inner
  $note.Margin=New-UiPadding 0 0 0 $script:UiSpace.Inset
  $settings.Controls.Add($note)
  $state.Apply=Add-SidebarButton $settings '변경 적용 · 화면 재연결' 'apply' 'primary'
  $state.Apply.Reconnects=$true
  $state.Save=Add-SidebarButton $settings '지금 실행 중인 설정 저장' 'save'
  $state.Restore=Add-SidebarButton $settings '정상 설정으로 복원' 'restore'
  $state.Restore.Reconnects=$true; $state.Restore.Margin=New-UiPadding 0 0 0 0
  $layout.Controls.Add($screen)

  $layout.Controls.Add((New-UiText '연결' 'section'))
  $connection=New-UiCard 0
  if (-not (Test-WirelessSerial $Config.serial)) { $state.Wireless=Add-SidebarRow $connection '무선으로 전환 · 케이블 없이 사용' 'wireless' 'wifi' '' -Reconnects }
  $state.AddDevice=Add-SidebarRow $connection '다른 휴대폰 추가 연결 · 새 창에서 연결합니다' 'adddevice' 'plus' 'chevron-right'
  $state.AddDevice.Divider=[bool]$state.Wireless
  $layout.Controls.Add($connection)

  # Occasional help as one line of links, then the legend that explains the reconnect glyph once for the window.
  $help=New-Object Windows.Forms.FlowLayoutPanel
  $help.AutoSize=$true; $help.Dock='Top'; $help.WrapContents=$true; $help.Margin=New-UiPadding 0 0 0 4
  foreach ($item in @(@('Discord 방송 길라잡이','help','broadcast'),@('문제 정보 저장','export','file'),@('업데이트 확인','update','update'))) {
    $button=New-UiButton $item[0] $item[1] 'link' $item[2]
    $button.Margin=New-UiPadding 0 0 $script:UiSpace.Inset 0
    $button.Add_Click({ Invoke-SidebarAction $this })
    $help.Controls.Add($button)
    if ($item[1] -eq 'update') { $state.Update=$button } elseif ($item[1] -eq 'export') { $state.Export=$button }
  }
  $layout.Controls.Add($help)
  $legend=New-UiText '화면이 잠시 다시 연결되는 작업입니다. Discord에서는 공유 창을 다시 골라야 할 수 있습니다.' 'caption' $width
  $legend.Glyph='reconnect'
  $layout.Controls.Add($legend)
  $closing=New-UiText '이 창의 X는 메뉴만 최소화합니다. 미러링을 끝내려면 영상 창의 X를 누르십시오.' 'caption' $width
  $closing.Glyph='info'
  $layout.Controls.Add($closing)

  $state.Lock.Add_CheckedChanged({ Update-SidebarState $this.FindForm().Tag })
  $form.Tag=$state
  Update-SidebarState $state
  # Recording time and a slow blink (off when Windows animation effects are off).
  if ($script:Recording) {
    $script:SidebarClock=New-Object Windows.Forms.Timer; $script:SidebarClock.Interval=500
    $script:SidebarClockState=$state
    $script:SidebarClock.Add_Tick({ Update-SidebarClock $script:SidebarClockState })
    Update-SidebarClock $state; $script:SidebarClock.Start()
    $form.Add_Disposed({ if ($script:SidebarClock) { $script:SidebarClock.Dispose(); $script:SidebarClock=$null } })
  }
  $form.Add_Shown({ Fit-Sidebar $this })
  Complete-UiForm $form
  $form.Add_FormClosing({ if ($_.CloseReason -eq [Windows.Forms.CloseReason]::UserClosing) { $_.Cancel=$true; $this.WindowState='Minimized' } })
  return $form
}
function Get-SidebarExpandText {
  if ($script:SidebarExpanded) { '화면 설정 접기 · 바꾼 값은 적용하기 전까지 점선으로 표시됩니다' } else { '화면 설정 펼치기 · 선명도, 프레임, 전송량, 완충, 압축, 소리' }
}
function Add-SidebarRow ($Card, [string]$Text, [string]$Key, [string]$Icon, [string]$Trail, [switch]$Reconnects) {
  $button=New-UiButton $Text $Key 'row' $Icon $Trail -Reconnects:$Reconnects
  $button.Dock='Top'; $button.Margin=New-UiPadding 0 0 0 0
  $button.Add_Click({ Invoke-SidebarAction $this })
  $Card.Controls.Add($button); return $button
}
function Add-SidebarButton ($Layout, [string]$Text, [string]$Key, [string]$Variant='secondary', [string]$Icon='') {
  $button=New-UiButton $Text $Key $Variant $Icon
  $button.Dock='Top'
  $button.Add_Click({ Invoke-SidebarAction $this })
  $Layout.Controls.Add($button); return $button
}
function Set-SidebarSaved ($State, [bool]$Saved) {
  Set-UiText $State.SavedChip $(if ($Saved) {'저장된 설정'} else {'이번 실행에만 쓰는 설정'})
  $State.SavedChip.Glyph=if ($Saved) {'check'} else {'pencil'}
  $State.SavedChip.Tone=if ($Saved) {'success'} else {'neutral'}
  $State.SavedChip.Invalidate()
}
# Live lock: every action that reconnects shows a lock instead of its glyph and cannot be pressed; the chip says why.
function Update-SidebarState ($State) {
  $locked=$State.Lock.Checked
  foreach ($button in @($State.Apply,$State.Restore,$State.Record,$State.Guide,$State.Source,$State.Wireless)) {
    if ($button) { $button.Enabled=-not $locked; $button.Locked=$locked; $button.Invalidate() }
  }
  $State.LockChip.Visible=$locked
  Update-SidebarDraft $State
}
# Pencil and ink: values picked but not applied are dashed and counted; with nothing picked, Apply only reconnects.
function Update-SidebarDraft ($State) {
  $count=0
  foreach ($key in $State.Fields.Keys) {
    $combo=$State.Fields[$key]; $changed=([string]$combo.SelectedItem -ne $State.Initial[$key])
    if ($combo.Changed -ne $changed) { $combo.Changed=$changed; $combo.Invalidate() }
    if ($changed) { $count++ }
  }
  $required=($State.Required.Checked -ne ($State.Config.requireaudio -eq '1'))
  if ($State.Required.Changed -ne $required) { $State.Required.Changed=$required; $State.Required.Invalidate() }
  if ($required) { $count++ }
  $State.DraftCount=$count
  if ($count) {
    Set-UiText $State.Draft "적용하지 않은 값 $($count)개"; $State.Draft.Glyph='pencil'; $State.Draft.ForeColor=Get-UiColor 'Text'
    Set-UiText $State.Apply '변경 적용 · 화면 재연결'; $State.Apply.Variant='primary'
  } else {
    Set-UiText $State.Draft '지금 실행 중인 값입니다.'; $State.Draft.Glyph='check'; $State.Draft.ForeColor=Get-UiColor 'Muted'
    Set-UiText $State.Apply '같은 설정으로 다시 연결'; $State.Apply.Variant='secondary'
  }
  $State.Draft.Invalidate(); $State.Apply.Invalidate()
}
function Update-SidebarClock ($State) {
  if (-not $State -or -not $script:Recording) { return }
  $elapsed=if ($script:RecordStarted) { [DateTime]::Now-$script:RecordStarted } else { [TimeSpan]::Zero }
  $clock=if ($elapsed.TotalHours -ge 1) { '{0}:{1:mm\:ss}' -f [int][Math]::Floor($elapsed.TotalHours),$elapsed } else { '{0:mm\:ss}' -f $elapsed }
  Set-UiText $State.RecChip "녹화 중 $clock"
  $blink=[MxTheme]::Motion -and ([DateTime]::Now.Millisecond -ge 500)
  $State.RecChip.GlyphOff=$blink; $State.Record.LampOff=$blink
  $State.RecChip.Invalidate(); $State.Record.Invalidate()
}
function Fit-Sidebar ($Form) {
  # Height follows content (folded or not), capped by the screen; the window scrolls beyond that.
  # Only the height changes: re-applying a client width measured while a scrollbar shows would shrink the menu.
  $layout=$Form.MxLayout; $scroll=$layout.Parent; $layout.PerformLayout()
  $width=$scroll.ClientSize.Width+$(if ($scroll.VerticalScroll.Visible) { [Windows.Forms.SystemInformation]::VerticalScrollBarWidth } else { 0 })
  $preferred=$layout.GetPreferredSize((New-Object Drawing.Size($width,0))).Height
  $area=[Windows.Forms.Screen]::FromControl($Form).WorkingArea
  $chrome=$Form.Height-$Form.ClientSize.Height
  $Form.Height=[Math]::Min($preferred+4+$chrome,$area.Height-24)
}
function Invoke-SidebarAction ($Button) {
  $s=$Button.FindForm().Tag
  if ($Button.Tag -in @('apply','record','restore','guide','source','wireless') -and $s.Lock.Checked) { Set-UiStatus $s.Status '방송 잠금을 먼저 해제해 주십시오.' 'danger'; return }
  try {
    switch ($Button.Tag) {
      'expand' {
        $script:SidebarExpanded=-not $s.Settings.Visible
        $s.Settings.Visible=$script:SidebarExpanded
        Set-UiText $Button (Get-SidebarExpandText)
        Set-UiButtonStyle $Button 'row' 'sliders' $(if ($script:SidebarExpanded) {'chevron-up'} else {'chevron-down'})
        Fit-Sidebar $Button.FindForm()
      }
      'apply' { $candidate=Get-SidebarConfig $s; $s.Request=@{Kind='apply';Config=$candidate} }
      'record' { $s.Request=@{Kind='record'} }
      'guide' { $s.Request=@{Kind='guide'} }
      'source' { $source=Select-MirrorSource $Button $s.Status $s.Config.serial; if ($source) { $s.Request=@{Kind='source';Source=$source} } }
      'wireless' {
        Invoke-UiBusy $Button $s.Status '무선 연결로 전환하는 중입니다…' {
          $serial=Switch-ToWireless $env:ADB $s.Config.serial
          $script:Notice=@{Text='무선으로 전환했습니다. 이제 케이블을 뽑아도 됩니다.';Tone='success'}
          $s.Request=@{Kind='serial';Serial=$serial}
        }
      }
      'adddevice' { $message=Start-AdditionalDevice $s.Config.serial; Set-UiStatus $s.Status $message 'info' }
      'screenshot' { Invoke-UiBusy $Button $s.Status '스크린샷을 저장하는 중입니다…' { $path=Save-Screenshot $s.Config.serial; Set-UiStatus $s.Status "스크린샷을 저장했습니다.`n$path" 'success' $path } }
      'save' { Save-Config $s.Config; Set-SidebarSaved $s $true; Set-UiStatus $s.Status '지금 실행 중인 설정을 저장했습니다. 아직 적용하지 않은 선택값은 저장하지 않습니다.' 'success' }
      'restore' { $candidate=Read-Profile 'good' $s.Config.serial; if (-not $candidate) { throw '저장된 정상 설정이 없습니다. 도우미에서 먼저 화면을 확인해 주십시오.' }; $s.Request=@{Kind='apply';Config=$candidate} }
      'help' { Show-BroadcastHelp }
      'update' { Invoke-UiBusy $Button $s.Status '업데이트를 확인하는 중입니다…' { try { $r=Get-UpdateStatus; Set-UiStatus $s.Status $r.Text $r.Tone } catch { Set-UiStatus $s.Status '업데이트를 확인하지 못했습니다. 인터넷 연결을 확인해 주십시오.' 'danger' } } }
      'export' { $path=Export-Diagnostics $s.Config; Set-UiStatus $s.Status "문제 정보를 저장했습니다.`n$path" 'success' $path }
      'open' {
        $path=[string]$s.Status.MxPath
        if (-not $path -or -not (Test-Path -LiteralPath $path)) { throw '파일을 찾지 못했습니다. 옮기거나 지웠을 수 있습니다.' }
        Start-Process -FilePath (Join-Path $env:SystemRoot 'explorer.exe') -ArgumentList "/select,`"$path`""
      }
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
