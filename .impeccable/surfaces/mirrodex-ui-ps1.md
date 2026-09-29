---
version: 1
slug: "mirrodex-ui-ps1"
primary_target: "mirrodex-ui.ps1"
related_targets: ["mirrodex-guide.ps1"]
---

# Surface: Mirrodex desktop UI (side menu, assistant dialogs, trial strip, pickers, forms)

Mode: Operate. Platform: native Windows (PowerShell 5.1 + WinForms, owner-drawn). No web surface.
Audience/job: everyday phone mirroring (incl. beginners) and Discord streaming/recording, equally weighted (confirmed).
Constraints: every existing feature, rule, file and result preserved; Korean source strings with English lookup; light/dark/high contrast; 100–150% DPI; folded side menu fits 1200px screen at 125%.

## Direction contract

THESIS: Settings are a prescription refined by "one or two?". The UI is a ruled record card of what is showing now, plus a lens track that compares one change at a time. It refuses the stacked equal-weight button column (the category default) and the neon gamer HUD (its opposite).

OWN-WORLD: Cool chart-room neutrals, ink (near-black / near-white) for text and the single commit action, graphite dashes for unapplied "pencil" values, amber lamp (the logo's eyes) for anything switched on, REC red only for recording, green only for "saved". Hairline-ruled label/value rows with tabular readouts, circular lens discs with numerals, 2x2 lamp keys, command-link answers, quiet "other options" rows, one drawn 16px icon set, one reconnect glyph that marks every action which interrupts the picture.

STORY: At a glance the user knows what is shown, whether it records, whether reconnection is locked, and whether the running settings are saved. Frequent actions are keys; tuning happens through the assistant whose trials read 1 · 2 · 1; nothing is saved without an explicit "better".

FIRST VIEWPORT: Side menu docked beside the mirror: header (logo, name, language); Now card (source icon, source headline, Change action; readout of px/fps/rate/codec/connection; state chips; message line with open-folder action); 2x2 keys (record, screenshot, on top, live lock); ruled rows (assistant, screen settings fold, wireless, another phone); footer links and the reconnect legend. No primary until a draft exists; then "Apply" is the ink primary.

FORM: Optometrist refraction record ("one or two?" + prescription card), position 3 of 7 on the grounded list; seed key 2264c92c. Raises: creator-hardware bench → keys whose lamp is the state, one accent for commit; darkroom exposure record → states readable without colour (dashed = draft, lock glyph = blocked, filled/hollow lamp); oscilloscope → one measured grid, shared icon and text columns; CD-ROM console → the UI frames the live window and never covers it (trial strip docks beside the trial mirror).

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Verdicts
- Sneaker box wall: declined (audience, clarity). Kept: one label grid rules every row.
- Gravity rain garden: declined. Kept: the one legend held level (reconnect legend fixed in the footer).
- Darkroom exposure record: competitive (clarity). Raise above.
- Oscilloscope bench: declined. Raise above.
- CD-ROM chrome console: declined. Raise above.
- Creator-hardware bench: competitive (clarity). Raise above.
- Not shown as a card (brief asked for one recommended direction): phone camera viewfinder grammar, my top grounded candidate; familiar, strong for recording, weaker for the comparison mechanism.
