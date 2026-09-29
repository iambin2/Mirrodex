Mirrodex — Phone screen mirroring with a step-by-step assistant, even for first-time users
========================================================================================
(한국어 안내: README.txt)

Getting started
  1. Unblock the ZIP before extracting it.
     Right-click the downloaded ZIP file and open 'Properties'.
     Next to 'Security: This file came from another computer…' at the bottom, check 'Unblock', then click 'OK'.
     (If there is no 'Unblock' option, the file is already unblocked.)
  2. Right-click the ZIP file and choose 'Extract All'.
     Do not run it from inside the ZIP; open the extracted folder.
  3. Unlock your phone and connect it to the computer with a cable.
  4. Double-click 'Install Mirrodex.bat' to install Mirrodex on this PC with Start menu and desktop shortcuts.
     (To use it without installing, double-click Mirrodex.bat.)
  5. The phone screen appears right away, starting with defaults for your connection (cable or wireless).
     If the screen is uncomfortable, click 'Tune the screen with the assistant' in the side menu.

  If a blue 'Windows protected your PC' window appears
    Mirrodex is not code-signed yet, so Windows warns about an app it has not seen before.
    Click 'More info', then 'Run anyway'.
    If you already extracted the files, the simplest fix is to unblock the ZIP as in step 1,
    delete the extracted folder and extract it again.

What the assistant does
  · The mirroring engine is included in the folder, so there is nothing else to install.
  · If the phone is not connected, it explains the cable and phone settings.
  · If the phone needs to allow the connection, it tells you what to tap.
  · After showing the screen for 30 seconds, it asks: 'Looks good / Motion keeps stuttering /
    Text or screen looks blurry / Response after tapping is slow'.
  · It changes one setting at a time to match the problem and compares. No numbers or jargon needed.
  · It saves only settings you chose as better. If similar or unsure, the current values are kept.

The screen closing during a trial is not a fault
  The trial screen closes automatically after 30 seconds and returns to the assistant.
  A comparison runs current → changed → current screen, about 90 seconds in total.
  Do the same thing in the same app. Compare text, motion and response together.
  The phone's own screen may turn off. Control the screen shown on the computer with the mouse.
  If the phone is locked, press its power button and unlock it.

Everyday use
  Click Mirrodex on the desktop to start right away with your saved settings.
  Control the phone by clicking or dragging with the mouse. To finish, click X on the mirroring window.

Getting help again
  Click 'Tune the screen with the assistant' in the menu next to the mirror. Mirroring can stay on.
  If the screen does not open at all, choose 'Tune the screen again with the assistant' in the message window.
  (The separate 'Mirrodex 도우미' shortcut of earlier versions is no longer needed and is removed automatically.)
  If the screen already looks good, there is no need to change anything.
  Closing the assistant does not save trial settings you have not confirmed.
  Settings you already saved with 'The changed screen is better' are kept.

If it is still uncomfortable
  · Plug the cable directly into the computer. If the cable only charges, try another cable.
  · If wireless, move closer to the router. A cable connection is easier at first.
  · Check whether it also stutters on the phone itself. If the phone is hot, let it rest and try again.
  · If text is small, enlarge the mirroring window on the computer.
  The assistant compares up to five changes at a time. Perfect performance is not guaranteed in every setup.

Allowing the phone connection
  When the assistant asks, turn on USB debugging on the phone:
  tap Settings > About phone > Software information > Build number 7 times,
  then turn on Settings > Developer options > USB debugging.
  Allow the connection only on a computer you own and trust.
  If Samsung Auto Blocker locks the setting, check its option for blocking USB commands.

For experienced users
  Mirrodex.bat guide     Button-based assistant
  Mirrodex.bat setup     Choose starting settings for your setup (can keep current settings)
  Mirrodex.bat tune      Compare items one by one
  Mirrodex.bat diagnose  Show device information
  Starting points for a new setup: USB 1024/60fps/8M/50ms, wireless 1024/60fps/6M/100ms,
  low load 800/30fps/4M/50ms. The device's hardware encoder list and resolution are applied.
  Existing user settings are kept. The refresh rate is never forced based on the model name.
  Wireless connection and pairing are not done automatically.

Shortcuts
  Alt+F full screen / Alt+H home / Alt+B or Alt+Backspace back
  Alt+O turn phone screen off / Alt+Shift+O on / Alt+I show FPS

Settings and restore
  mirrodex.cfg: saved settings. You do not need to edit it.
  mirrodex.cfg.bak: the file before settings were changed.
  refresh-recovery.cfg: restore record of the old refresh-rate forcing feature. Do not delete it.
  If this record remains, reconnect that phone and run Mirrodex to complete the restore.
  The old arr option is read only for compatibility and never changes the phone's refresh rate.
  The mirroring FPS cap is kept separately.

Features kept from before
  Mouse and keyboard, clipboard, sound forwarded to the computer, phone screen off,
  no sleep while charging, no PC screensaver, desktop shortcuts.

Design notes: REVIEW.md (Korean)
Built-in engine: the engine folder = official scrcpy 4.1 win64 release (SHA-256 verified,
  executable renamed mirrodex-engine.exe) + adb (renamed mirrodex-adb.exe).
  scrcpy https://github.com/Genymobile/scrcpy (Apache-2.0, engine/LICENSE.txt)
  Mirrodex does not run without the engine folder. Extract the ZIP again.

Recovery and setup guidance (2026-09-28)
  · Existing users also see button-based guidance when there is no connection or permission is needed.
  · The assistant's first screen offers 'Use current settings without saving',
    'Restore settings that worked' and 'Undo the last settings change'.
  · The settings first confirmed with 'Looks good' are kept separately as the known-good restore point.
    Later ordinary saves do not overwrite it. It is replaced only when you choose
    'Set the current screen as known-good and use it' from 'Finish another way'
    under the assistant's 'Other options'.
  · A comparison can run for 30 or 10 seconds. Skipping or stopping never adopts new settings.
    Comparisons are shown as 1 · 2 · 1 discs (1 = current, 2 = changed). The trial window sits next to
    the mirror window with a line that shrinks as time runs out, and the window keeps its position and size.
  · After five comparisons you can finish with temporary use, restore or saving troubleshooting info.
  · A disconnection asks you to reconnect the same phone. Only when an encoder failure is clear,
    another encoder from the device's list is offered once, and it is never saved without your confirmation.
  · Setups are told apart by phone, PC, USB or wireless, and the chosen display's name and resolution,
    based on the monitor where the mouse is at launch. Changes in monitor refresh rate, GPU driver,
    cable quality or wireless congestion are not detected; use the assistant again in that case.
  · In the profiles folder, good.cfg is the known-good restore point and previous.cfg the last settings.
    Normal users do not need to edit these files.
  · 'Save troubleshooting info' writes settings, error type and an FPS summary of recent runs to the
    diagnostics folder. FPS logging is on only during short trials. Low FPS on a still screen can be
    normal, and skipped frames are not a network loss rate. Settings are never adopted from numbers alone.
    Screen content, clipboard, device serial numbers and raw logs are not included and nothing is uploaded.
  · Updates do not stop a screen that is already running. They apply from the next launch.

Tests: tests/regression.ps1, tests/guide.ps1, tests/scenarios.ps1, tests/language.ps1, tests/features.ps1
New-PC / first-time-user check procedure: tests/ACCEPTANCE.md (Korean)
Audio: while mirroring, the phone's playback sound goes to the PC's default output device.
  If headphones are connected to the computer, you hear it there. The microphone is not captured.

Side menu and Discord streaming
  When mirroring starts, a menu appears next to the video window. From the top:
  · Now card: what is shown ('Change' next to it), resolution, fps, bit rate and codec, the phone and
    connection, state chips (recording time, reconnection locked, 'Saved settings' or 'This session only'),
    and the result of your last action. After a screenshot, recording or troubleshooting file is saved,
    'Open file location' opens its folder.
  · Four keys: screen recording, 'Save screenshot' (Pictures\Mirrodex, mirroring keeps running),
    'Keep on top' and 'Live · Lock reconnects'. On/off keys show a small circle at the top right:
    filled when on, hollow when off.
  · Screen: 'Tune with the assistant' opens the comparison assistant during mirroring, then mirroring
    continues. Screen settings are folded. Click 'Show screen settings' to choose
    resolution, frame cap, bit rate, video/audio buffer, codec and sound output.
  · Connection: switch to wireless, connect another phone. Below: Discord guide, troubleshooting info, updates.
  Actions marked with ↻ briefly reconnect the screen.
  The screen keeps running while you choose values. Values chosen but not applied are dashed and counted.
  'Apply changes · Reconnect' reconnects briefly; with nothing changed the same button reads
  'Reconnect with the same settings'.
  Applied changes last only for this session. If you like them, click 'Save the running settings'.
  'Restore known-good settings' returns to the restore point you confirmed.
  While streaming, turn on 'Live · Lock reconnects' so the connection is not cut by mistake.
  While locked, reconnecting actions show a lock and cannot be pressed.
  The menu's X only minimizes the menu. You can reopen it from the taskbar.
  In Discord, choose the Mirrodex video window, not the settings window, and turn on sound sharing.
  After reconnecting, you may need to reselect the shared window in Discord.
  Detailed streaming notes and checks are in BROADCAST.md (Korean).

New features (2026-09-29)
  · Wireless: when the assistant says no phone is connected, click 'Connect wirelessly · No cable'
    and pair with the code under Wireless debugging (Android 11+).
    If the phone is on a cable, click 'Switch to wireless · Unplug the cable' in the menu, then unplug it.
  · What to show: 'Change' on the menu's Now card picks the whole phone screen, one app only,
    or the back/front camera. 'One app only' opens the app on a separate screen, so notifications and
    other apps never appear on stream (Android 10+). Camera mode uses the phone's microphone (Android 12+).
    In Discord, share this window.
  · Keep the mirror window on top: remembered for the next launch.
  · Connect another phone: each phone gets its own mirror window and menu. The same phone never opens twice.
  · Dark mode: follows the Windows app mode (light/dark).
  · Remove: Windows Settings > Apps > Mirrodex > Uninstall. Recordings and screenshots are kept.
  · Automatic updates: Mirrodex checks for a new version once a day at start and asks before installing.
    Settings, recordings and screenshots are kept. 'Check for updates' in the menu checks right away.
    Publishing a release (for the developer): RELEASING.md (Korean)
  Screen rules and the color, type and spacing system are in DESIGN.md (Korean).

Language (English / 한국어)
  The default language is English. Switch instantly with the '한국어' / 'English' button
  at the top right of every window. The choice is saved in preferences.cfg and kept for the next launch.
  Switching during mirroring does not interrupt the connection.

Screen recording (with sound)
  Click 'Record screen' in the side menu. The screen reconnects briefly, then recording starts.
  The Now card shows the recording time while it runs.
  Click 'Stop recording · Save file' or close the mirroring window to save the file.
  Saved to: Videos\Mirrodex\Mirrodex-date-time.mp4
  Sound is recorded when 'Sound output' is Computer. When set to Phone, only video is recorded.
  Applying settings while recording splits the recording into a new file at each reconnection.
  With the h265 video codec, some PCs' default player may need the HEVC extension.
  In that case switch to h264 in the side menu before recording, or play the file with VLC or similar.
  Recording cannot be started or stopped while the streaming lock is on.
  The assistant's comparison trials are never recorded.

Appearance
  One design (ruled rows like a record card, 1 · 2 · 1 comparison discs, on/off lamps) applies to the
  assistant, connection/error messages, comparison screens and the side menu. The font is Pretendard
  when installed; otherwise Malgun Gothic for Korean and Segoe UI for English. Standard Windows window
  frames, keyboard control (Enter = recommended answer, Esc = close), screen readers, high contrast
  and the 'Animation effects' setting are respected.

2026-09-29 changes: guide windows open to fit their actual content height after DPI scaling;
  long messages scroll. The logo is scaled down from a 256px original with high-quality
  interpolation so it stays smooth at any scale. The phone refresh-rate forcing feature was removed;
  existing restore records are still recovered. The current user's refresh-rate repair request is kept
  separately in refresh-repair.cfg, applied once when that SM-S948N connects, and deleted after verification.
