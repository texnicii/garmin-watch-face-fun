# CLAUDE.md — Watch Face «Fun Bra» (design «01 · Неон-кольца»)

Guidance for working in this repo. Read this first.

## What this is

A **Garmin watch face** for **AMOLED** smartwatches. Concept — a playful neon
face: a big thin digital clock with weekday + date on top, and two mirrored
glowing curves ("cups") meeting at the center, each with a blinking dot
inside. The curves are **progress indicators** (steps to goal / active minutes
today / battery, chosen per curve) with a caption + percent under each — or,
in decorative mode, always full with no readouts. Four color pairs.
Bilingual: **English + Russian**; the app name is «Fun Bra» in both.

The canonical design is `design/neon-rings/Neon.dc.html` (+ `reference.png`),
codified in the `neon-rings-face` skill (`.claude/skills/neon-rings-face/`) —
**always consult that skill before touching rendering code.**

## Toolchain (already installed — do not reinstall)

| Thing | Value |
|---|---|
| Connect IQ SDK | **9.1.0** (compiler reports `9.1.0`) |
| SDK path | `~/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b/` |
| Devices installed | 68 (see `~/Library/Application Support/Garmin/ConnectIQ/Devices/`) |
| Java | `/opt/homebrew/opt/openjdk@11/bin/java` (CIQ tools need Java 11) |
| Signing key | `developer_key` (DER) + `developer_key.pem` — repo root (copied from `../wf`), **git-ignored**, never commit |

The SDK path contains spaces. Put the SDK `bin/` on `PATH` for a shell session:

```bash
export CIQ_BIN="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.1.0-2026-03-09-6a872a80b/bin"
export PATH="$CIQ_BIN:$PATH"
export JAVA_HOME="$(/usr/libexec/java_home -v 11 2>/dev/null || echo /opt/homebrew/opt/openjdk@11)"
```

### Build / run / package

```bash
# Compile for ONE device (debug, strict typecheck). -l 3 = strict.
monkeyc -f monkey.jungle -o bin/wf_funbra.prg -y developer_key -d venu3 -l 3 -w

# Launch the simulator GUI once (leave it running), then load the build:
connectiq                           # starts ConnectIQ.app
monkeydo bin/wf_funbra.prg venu3    # side-loads .prg into the running sim

# Store package (.iq, all listed products, release/stripped):
monkeyc -f monkey.jungle -o bin/wf_funbra.iq -y developer_key -e -r -w
```

Check one device per resolution bucket before calling a change done: `venu3`
(454), `fr265` (416), `venu3s` (390), `fr265s` (360), `venux1` (448×486 rect).

### Products (`manifest.xml`)

The 40 products are every installed device that is **AMOLED**, supports
watch faces, lists Russian, has API ≥ 5.1 and a screen we have font buckets
for (round 360/390/416/454, or `venux1`). Find candidates from each device's
`~/Library/Application Support/Garmin/ConnectIQ/Devices/<id>/compiler.json`
(`displayType`, `resolution`, `appTypes`, `partNumbers[].connectIQVersion`).
Deliberately **excluded**: MIP watches (fēnix 7/8 Solar, FR 255/955, Enduro 3:
218–280 px screens need new font buckets, and their 64-color palette bands the
pre-mixed glow), monochrome Instinct 3 Solar / Instinct E, and Edge/eTrex (no
watch faces). Venu 2 family etc. are below API 5.1 and not installed.

Useful `monkeyc` flags: `-d <device>`, `-f <jungle>`, `-o <out>`, `-y <key>`,
`-l <0..3>` typecheck (0 off → 3 strict), `-O <0..3/p/z>` optimize, `-r` release
(strip debug), `-e` package app (.iq), `-w` warnings, `-g` debug, `-t` unit tests.

> Prefer the **VS Code “Monkey C” extension** for day-to-day F5 run/debug; the
> CLI above is the source of truth for CI and headless builds.

## Project layout

```
manifest.xml              # app id/type=watchface, 40 AMOLED products, languages, minApiLevel=5.1.0
monkey.jungle             # build config; project.typecheck=strict
source/
  FunBraApp.mc            # AppBase: getInitialView(), getSettingsView(), onSettingsChanged()
  FunBraView.mc           # WatchFace: lifecycle, settings cache, data, blink timer
  FunBraDelegate.mc       # WatchFaceDelegate: onPowerBudgetExceeded()
  Layout.mc               # design px -> screen (s/450), curve polylines, bbox
  Theme.mc                # color tokens, PALETTES, mix() pre-blend over the field
  model/FaceData.mc       # per-frame snapshot for the renderers
  model/Metrics.mc        # curve metrics: steps / active minutes / battery -> percent
  render/Curve.mc         # stroke up to pct as one outline polygon + round caps; track + neon glow
  render/CurveLayer.mc    # BufferedBitmap cache of both curves (direct-draw fallback)
  render/FaceRenderer.mc  # full high-power render
  render/AodRenderer.mc   # minimal always-on render (burn-in safe, pixel-shifted)
  settings/SettingsMenu.mc# on-device Menu2 (cycling rows + blink toggle)
resources/                # DEFAULT locale = English; 454 font sizes
  strings/ settings/ drawables/ fonts/
resources-round-{416x416,390x390,360x360}/fonts/   # per-resolution font sizes
resources-rus/strings/    # Russian bundle (see Localization)
tools/fonts/              # gen_fonts.py + src/JetBrainsMono-VF.ttf (see its README)
design/neon-rings/        # design export + reference.png
GARMIN_STORE.md           # store listing text + changelog
```

## AMOLED rules — NON-NEGOTIABLE

Every target device reports `screenProtectionSupport = true`. Garmin enforces
these in firmware and in store review:

1. **Always-On (AOD) mode is mandatory.** Many AMOLED users disable
   raise-to-wake; if we have no AOD path the face goes black. `AodRenderer`
   is that path — never remove it.
2. **AOD update budget:** in always-on mode the system updates **once per
   minute** and each update may light **≤ 10 %** of the display's pixels. AOD
   keeps just the thin clock, the date and curve hairlines — keep it that
   sparse (no glow, no filled dots, no thick strokes).
3. **Burn-in protection / pixel shift:** any element that is on every minute
   must move. The AOD layout shifts by up to **±2 px** per axis each minute
   (derived from the current minute). Don't draw the same lit pixels forever.
4. **AOD palette:** avoid large areas of **white or blue**; prefer light/medium
   **gray**, thin strokes, hollow shapes. Neon colors are high-power only.
5. **High-power window:** on wake the system gives ~10 s where you may run a
   `Timer` / animate. `onEnterSleep`/`onExitSleep` flip `_isAwake`; heavy
   drawing only when awake. The **dot blink timer** starts in
   `onExitSleep`/`onShow`, stops in `onEnterSleep` **and** `onHide`, and
   self-stops after 10 ticks. Never animate in AOD.
6. **Partial updates:** there is no seconds display, so no `onPartialUpdate`
   path. If one is ever added: per-call work < ~20 ms, `setClip()` to the
   changed rect then `clearClip()`, and `onPowerBudgetExceeded()` must fall
   back gracefully (the delegate hook is already wired).

Detect/branch with `System.getDeviceSettings().requiresBurnInProtection` and
the wake flags. **When in doubt, render less.**

## Monkey C essentials & gotchas

- Object-oriented, dynamically + (optionally) statically typed; types in
  `as`/`Toybox.Lang` annotations. Keep `project.typecheck = strict`.
- `import Toybox.Xxx;` (whole module) or `using Toybox.Xxx as Y;`. Symbols are
  `:like_this`. Resources are reached via `Rez.*` and `WatchUi.loadResource()`.
- **Memory is tiny** (watch faces have the smallest budget of all app types).
  Allocate in `initialize()` / `onLayout()`, **not** in `onUpdate()`. Curve
  polylines are precomputed in `Layout`; the curve layer lives in the graphics
  pool (`Graphics.createBufferedBitmap`) and is redrawn only when a percent or
  the palette changes. Avoid per-frame `String` building beyond the few
  readouts and array churn — it triggers GC stalls.
- `onUpdate(dc)` runs once/minute in low power (and once/second during the
  blink); treat it as the hot path. No network, no heavy math, no allocations.
- Guard every optional API with `has`: `if (dc has :setAntiAlias)`,
  `if (Graphics has :createBufferedBitmap)`. Devices/firmware vary; unguarded
  calls crash on devices that lack them. A `BufferedBitmapReference.get()` can
  return null after a pool purge — `CurveLayer` rebuilds.
- `Math.sqrt` returns a Double: `.toFloat()` before storing in `Array<Float>`
  under strict typecheck.
- Watch faces **cannot** take user input (no buttons/taps) and **cannot** use
  most background/comm permissions. This face needs none (`<iq:permissions/>`
  is empty — keep it that way; Body Battery etc. would need `SensorHistory`).
- Data: `ActivityMonitor.getInfo()` (steps, stepGoal, activeMinutesDay,
  activeMinutesWeekGoal — all nullable) and `System.getSystemStats().battery`.
- Text uses the generated JetBrains Mono bitmap fonts (`tools/fonts/`); never
  hand-edit the `.fnt`/`.png` — edit and rerun `gen_fonts.py` (Pillow lives in
  Xcode's `/Applications/Xcode.app/Contents/Developer/usr/bin/python3`).

## Localization (EN + RU)

- All user-visible text comes from **string resources**, never hard-coded.
  Pattern from `../wf`: the default bundle holds every in-face string twice —
  plain ids are always English, `*Ru` ids always Russian — so the in-app
  **Language** setting (Auto/EN/RU, `langMode`) can force either. The
  `resources-rus` bundle mirrors those values (to keep the build warning-free)
  and only translates the settings-UI labels.
- `rus` is listed in `manifest.xml <iq:languages>`. All targets support it.
- **Cyrillic + custom fonts:** the bitmap fonts embed Latin + Cyrillic
  uppercase. A new character in any string must be added to the font subset
  (`TEXT_CHARS` in `gen_fonts.py`), or it renders blank.
- Respect `DeviceSettings` prefs (`is24Hour`) before formatting; never assume 24h.

## Settings / configuration

| Property | Type / default | Values |
|---|---|---|
| `curveMode` | number, 0 | 0 = indicators, 1 = decorative (full curves, no readouts) |
| `leftMetric` | number, 1 | `Metrics`: 0 steps to goal, 1 active minutes today, 2 battery |
| `rightMetric` | number, 2 | same |
| `readouts` | boolean, true | captions + percent values under the curves (indicator mode only) |
| `palette` | number, 0 | index into `Theme.PALETTES` (0 = design turquoise/pink) |
| `langMode` | number, 0 | 0 Auto, 1 English, 2 Russian |
| `blink` | boolean, true | dots blink after wake |

- **Mobile settings** via `resources/settings/settings.xml` + `properties.xml`;
  read with `Application.Properties.getValue()` (`SettingsMenu.getNum/getBool`);
  react in `AppBase.onSettingsChanged()` → `FunBraView.applySettings()`.
- **On-device**: `SettingsMenu` (Menu2) presented by the system from the watch
  face picker; rows cycle values, blink is a `ToggleMenuItem`. Writes the same
  properties; `FunBraView.onShow()` re-reads them.
- Adding a color pair: append to `Theme.PALETTES`, a `setPalN` string (EN + RU),
  a `listEntry` in `settings.xml` and a branch in `SettingsMenu.paletteLabel()`.
- Adding a metric: a constant + branch in `Metrics.mc` (bump `COUNT`), a
  caption pair `capXxx`/`capXxxRu` (in `FunBraView.applySettings` order), a
  `setMetricXxx` label, and `listEntry`s for both curves — indices must match.

## Conventions

- Follow **Monkey Style** (SDK Core Topics → Monkey Style): 4-space indent,
  `PascalCase` types, `camelCase` members, leading `_` for privates,
  `SCREAMING` for constants.
- Keep `onUpdate` allocation-free; precompute in `onLayout`.
- Every new optional-API use gets a `has` guard.
- Build must pass `-l 3 -w` with **zero warnings** before it's "done". The one
  known, accepted exception is the launcher-icon scaling notice (the 100×100
  SVG is scaled to each device's icon size — same in `../wf`).
- Reference the design via the `neon-rings-face` skill; store listing +
  changelog via the `garmin-store-listing` skill (changelog: brief,
  user-facing only, newest first, EN + RU).

## Reference material

- Sibling `../wf` («Фазы дня») — origin of these rules, the font pipeline and
  the EN/RU string pattern. Sibling `../wf_simple_analog` — same rules, analog.
- Local SDK docs (authoritative for 9.1.0):
  `…/Sdks/<sdk>/doc/docs/{Core_Topics,User_Experience_Guidelines}/*.html` —
  esp. `User_Experience_Guidelines/Watch_Faces.html`, `…/Localization.html`,
  `Core_Topics/{Properties_and_App_Settings,Resources,Graphics,Manifest_and_Permissions}.html`;
  API reference `…/Sdks/<sdk>/doc/Toybox/*.html`.
- SDK samples to copy idioms from: `…/Sdks/<sdk>/samples/{Analog,ConfigurableWatchFace,AnimationWatchFace,Strings}`.
- Online: api-docs <https://developer.garmin.com/connect-iq/api-docs/>,
  Monkey C <https://developer.garmin.com/connect-iq/monkey-c/>,
  reference guides <https://developer.garmin.com/connect-iq/reference-guides/>.
