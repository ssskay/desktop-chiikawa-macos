# Desktop Chiikawa for macOS 🍙 — Chiikawa Desktop Pet for Mac

![Downloads](https://img.shields.io/github/downloads/ssskay/desktop-chiikawa-macos/total?label=downloads&color=ff69b4) ![Release](https://img.shields.io/github/v/release/ssskay/desktop-chiikawa-macos?label=latest&color=8fd3f4) ![Platform](https://img.shields.io/badge/platform-macOS%20(Apple%20Silicon%20%26%20Intel)-black)

<!-- sarakay.me/downloads -->
**[⬇ Download for Mac (Apple Silicon)](https://sarakay.me/get/chiikawa-pet/mac-arm64)** · **[⬇ Download for Mac (Intel)](https://sarakay.me/get/chiikawa-pet/mac-intel)** · [all formats & checksums](https://sarakay.me/downloads.html#chiikawa-pet)

**A Chiikawa desktop pet that runs natively on Mac.** If you searched for *"chiikawa desktop pet macOS"* and only found Windows downloads — this is the Mac version. No Windows, no emulator, no Wine: a real macOS app for Apple Silicon (M1/M2/M3/M4) and Intel Macs.

ちいかわのデスクトップペット、Mac版です 🐰 (macOS ネイティブアプリ・Apple Silicon対応)

This is a native macOS port of [**Desktop Chiikawa**](https://cookieelmo.itch.io/desktop-chiikawa) by [**CookieElmo**](https://cookieelmo.itch.io), originally released for Windows in 2025.

All credit for the original app — the concept, art integration, reminder system, skins, and multi-language support — belongs to CookieElmo, who made it free for the Chiikawa community. If you enjoy this, please visit the [original itch.io page](https://cookieelmo.itch.io/desktop-chiikawa) and consider supporting them (it's name-your-own-price!).

## ⬇️ Download (Mac)

Two builds — grab the one for your Mac:

- **Apple Silicon (M1/M2/M3/M4):** [ChiikawaPet-AppleSilicon.dmg](https://github.com/ssskay/desktop-chiikawa-macos/releases/latest/download/ChiikawaPet-AppleSilicon.dmg)
- **Intel Macs:** [ChiikawaPet-Intel.dmg](https://github.com/ssskay/desktop-chiikawa-macos/releases/latest/download/ChiikawaPet-Intel.dmg)

Not sure which? Apple menu → About This Mac — an "Apple M-series" chip means Apple Silicon; "Intel" means Intel. Open the DMG and drag ChiikawaPet to Applications. The app is **signed and notarized by Apple**, so just double-click to open — no right-click needed. macOS 10.13+.

## 🪟 On Windows?

You want the original! Download it straight from CookieElmo: [Desktop Chiikawa on itch.io](https://cookieelmo.itch.io/desktop-chiikawa).

## ✨ What it does

Your Chiikawa friend wanders your desktop, delivers gentle wellness reminders (hydrate! stretch!), and chats in kaomoji speech bubbles. Reach the menu three ways — right-click the pet, the **menu-bar tray icon** (top-right), or the **app menu bar** (top-left):

- **Skins**: Chiikawa, Hachiware, Usagi, Goblin, Momonga — each speaks with their real catchphrases (Ura! Yaha!)
- **Size**: Small → **Giant** — make your pet as big as you like
- **Languages**: English, 日本語
- **Reminders**: wellness + productivity nudges at a configurable interval — or set your **own custom reminder message**
- **Give Snack** 🍙 and petting (quick click) reactions
- **Wander around** toggle — let them roam or stay put

## 🔧 Changes in this port (vs. the original Windows version)

- Runs natively on macOS via the official Godot 4.4.1 runtime (no emulation), signed + notarized, with separate Apple Silicon and Intel builds
- Adjustable pet size (up to Giant), plus a native menu-bar tray icon and app menu bar — not just right-click
- Custom reminder messages on top of a bigger wellness + productivity nudge pool
- Remembers position, skin, language, size, and reminder settings between launches
- Autonomous wandering with a menu toggle
- Petting and snack interactions with per-character voices
- Time-aware greetings, kaomoji instead of emoji
- Click-through everywhere except the sprite, so the pet never blocks your work

## 🛠 Building from source

The `recovered/` folder contains the Godot 4.4.1 project. Open it in the Godot editor (or use the bundled `export_presets.cfg`) and export for macOS.

**A clean export is not byte-identical to the currently shipped pck — and that's expected.** A normal Godot export compiles the GDScript to bytecode (`main.gdc`), whereas the shipped pck carries plain-source `main.gd` (it was post-processed with `tools/repack_pck.py`). The two are **functionally equivalent**; the clean export is actually the cleaner artifact. `repack_pck.py` is only needed if you want a bit-for-bit reproduction of the older pck — which normal builds do not require.

To reproduce the release exactly, `scripts/release.sh` exports the universal build, `lipo`-thins it to Apple Silicon and Intel, and signs + notarizes + staples each into its own DMG. It needs a *Developer ID Application* certificate and a `notarytool` keychain profile; run `scripts/release.sh --dry-run` to build and sign locally without contacting Apple.

## ⚠️ Disclaimer

This is a non-profit fan project. Chiikawa and all associated characters are the intellectual property of Nagano — please support the official work. The original Desktop Chiikawa app is by CookieElmo; this repository exists only to bring their lovely work to Mac users, with gratitude. CookieElmo: if you'd like this port taken down, transferred to you, or changed in any way, say the word and it's done.
