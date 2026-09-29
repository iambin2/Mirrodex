# Product

<!-- impeccable:product-schema 1 -->

## Platform

windows

Native Windows desktop (Windows 10/11). Not web: no HTML/CSS surface exists.

## Stack

Existing codebase: Windows PowerShell 5.1 (also runs on PowerShell 7) + Windows Forms with owner-drawn controls
(`mirrodex-ui.ps1`, small C# types compiled with `Add-Type`). Bundled engine: scrcpy 4.1 (`engine/mirrodex-engine.exe`) and adb.
No installer framework, no extra runtime, no UI library download (confirmed constraint in REVIEW.md: "새 UI 라이브러리 설치 불필요").

## Users

Two audiences, confirmed as equally important (2026-09-29):

- **Everyday mirroring** — people who want their Android phone on the PC screen to see it larger and control it with mouse
  and keyboard, including first-time users who do not know USB debugging, codecs or bit rates.
- **Streaming and recording** — people who share the phone screen in Discord or record it; they need the picture never to
  change unexpectedly while live, and need to know whether they are recording.

Feature frequency inside the side menu was not confirmed by the user. Working assumption from code and docs: recording,
screenshot and "what to show" are frequent; the engine settings are occasional; assistant, wireless, another phone, help,
update and diagnostics are rare.

## Product Purpose

Mirrodex makes phone-to-PC mirroring work for someone who has never heard of scrcpy: it bundles the engine, walks the user
through connecting, starts with sensible settings, and fixes discomfort by comparing one change at a time (current → changed →
current) and saving only what the user said was better. Success: the phone appears, and every later change is one the user chose.

## Positioning

A guided companion around scrcpy, not a new mirroring engine. Its distinctive mechanism is the A/B/A comparison assistant
that asks about symptoms (stutter, blur, delay) instead of numbers, and never saves an unconfirmed setting.

## Operating Context

- The mirror itself is the scrcpy (SDL) window, which Mirrodex does not draw. Mirrodex draws: a side menu docked beside the
  mirror window, step-by-step assistant dialogs, trial windows during comparisons, pickers, input forms, install/update prompts.
- The side menu window must never be shared on stream (its title says so); Discord users share the mirror window only.
- Reconnecting the engine interrupts the picture and may force Discord viewers to reselect the window.
- Power users also use the console modes `setup`, `tune`, `diagnose` (`Mirrodex.bat <mode>`) and scrcpy shortcuts (Alt+F, Alt+H…).
- Language: English by default, Korean by toggle; Korean is the source language in code. Light/dark follows Windows.
- Typical screen observed: 1920×1200 at 125% scaling; the folded side menu must fit without scrolling there.

## Capabilities and Constraints

Mirroring with saved settings; first-run quick start; environment profiles per phone/connection/PC/display; comparison
assistant with known-good restore, undo, temporary use and diagnostics export; side menu: recording, screenshot, always on
top, broadcast lock, what to show (whole screen / one app / front or back camera), engine settings (resolution, fps, bit rate,
video buffer, audio buffer, codec, audio output, strict audio), apply/save/restore, wireless switch, pairing, another phone,
Discord guide, diagnostics, update check; per-user install/uninstall; GitHub Releases updates with checksum; refresh-rate
recovery. All behavior, files and rules must be preserved by any redesign.

## Brand Commitments

- The logo (`assets/mirrodex-logo.png`, teal gear with yellow eyes) is kept as is. Interface colors are free (confirmed).
- Voice: Korean formal 합쇼체; English sentence case. Errors say what happened and how to recover (existing DESIGN.md rule).
- The logo easter egg (five quick clicks → creator card) stays.

## Evidence on Hand

Real UI strings in Korean and English (`mirrodex-lang.ps1`), test suites under `tests/`, BROADCAST.md and REVIEW.md
observations from real use. No user research, usage analytics or measured task times exist; do not claim efficiency numbers.

## Product Principles

1. Never surprise the live picture: anything that reconnects, records or saves says so before it happens.
2. Save only what the user confirmed; temporary and saved states must be distinguishable.
3. Beginners get one question at a time; experienced users keep direct settings, shortcuts and console modes.
4. Behave like a Windows app: keyboard, focus, Esc/Enter, screen readers, DPI scaling, light/dark.

## Accessibility & Inclusion

Keyboard-complete flows, visible focus, screen-reader names on custom-drawn controls, text contrast in both themes,
state never shown by color alone, correct layout at 100–150% scaling and with long English strings.
