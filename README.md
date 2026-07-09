# Desktop Chiikawa for macOS 🍙 — Chiikawa Desktop Pet for Mac

![Downloads](https://img.shields.io/github/downloads/ssskay/desktop-chiikawa-macos/total?label=downloads&color=ff69b4) ![Release](https://img.shields.io/github/v/release/ssskay/desktop-chiikawa-macos?label=latest&color=8fd3f4) ![Platform](https://img.shields.io/badge/platform-macOS%20(Apple%20Silicon%20%26%20Intel)-black)

**A Chiikawa desktop pet that runs natively on Mac.** If you searched for *"chiikawa desktop pet macOS"* and only found Windows downloads — this is the Mac version. No Windows, no emulator, no Wine: a real macOS app for Apple Silicon (M1/M2/M3/M4) and Intel Macs.

ちいかわのデスクトップペット、Mac版です 🐰 (macOS ネイティブアプリ・Apple Silicon対応)

This is a native macOS port of [**Desktop Chiikawa**](https://cookieelmo.itch.io/desktop-chiikawa) by [**CookieElmo**](https://cookieelmo.itch.io), originally released for Windows in 2025.

All credit for the original app — the concept, art integration, reminder system, skins, and multi-language support — belongs to CookieElmo, who made it free for the Chiikawa community. If you enjoy this, please visit the [original itch.io page](https://cookieelmo.itch.io/desktop-chiikawa) and consider supporting them (it's name-your-own-price!).

## ⬇️ Download (Mac)

Grab **`ChiikawaPet.dmg`** from the [Releases](../../releases) page, open it, and drag ChiikawaPet to Applications. On first launch, right-click the app → Open (it's a free fan project, not notarized with Apple). Works on Apple Silicon and Intel Macs — macOS 10.13+.

## 🪟 On Windows?

You want the original! Download it straight from CookieElmo: [Desktop Chiikawa on itch.io](https://cookieelmo.itch.io/desktop-chiikawa).

## ✨ What it does

Your Chiikawa friend wanders your desktop, delivers gentle health reminders (hydrate! stretch!), and chats in kaomoji speech bubbles. Right-click the pet for the menu:

- **Skins**: Chiikawa, Hachiware, Usagi, Goblin, Momonga — each speaks with their real catchphrases (Ura! Yaha!)
- **Languages**: English, 日本語, 廣東話, 简体中文, 繁體中文
- **Reminders**: configurable interval wellness nudges
- **Give Snack** 🍙 and petting (quick click) reactions
- **Wander around** toggle — let them roam or stay put

## 🔧 Changes in this port (vs. the original Windows version)

- Runs natively on macOS via the official Godot 4.4.1 runtime (no emulation)
- Remembers position, skin, language, and reminder settings between launches
- Autonomous wandering with a menu toggle
- Petting and snack interactions with per-character voices
- Time-aware greetings, kaomoji instead of emoji
- Click-through everywhere except the sprite, so the pet never blocks your work

## 🛠 Building from source

The `recovered/` folder contains the Godot 4.4.1 project. Open it in the Godot editor and export for macOS, or repack the modified script into an existing pck using `tools/repack_pck.py`.

## ⚠️ Disclaimer

This is a non-profit fan project. Chiikawa and all associated characters are the intellectual property of Nagano — please support the official work. The original Desktop Chiikawa app is by CookieElmo; this repository exists only to bring their lovely work to Mac users, with gratitude. CookieElmo: if you'd like this port taken down, transferred to you, or changed in any way, say the word and it's done.
