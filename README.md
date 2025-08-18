# Chocoya Tadadak (formerly **Ticklings**)

> **타다닥** (ta-da-dak) is an onomatopoeia in Korean that mimics the rhythmic *tapping* sound of a mechanical keyboard.  **Chocoya Tadadak** brings that satisfying click-clack back to your fingertips.

Chocoya Tadadak is a lightweight macOS menu-bar app that plays delightful key-click sounds every time you press a key – fully updated for modern macOS and distributed with open-source love.

---

## Features

* Global keyboard event listener (requires Accessibility permission)
* Multiple sound themes (Bubble, Typewriter, Mechanical …)
* Live volume and theme switching via Settings window
* Runs entirely locally – **no login, no auto-start, no telemetry**
* Ships with a cute status-bar icon: `chocoya-tadadak.png`

---

## Prerequisites

| Tool | Recommended Version | Install with |
|------|---------------------|--------------|
| macOS | 12 Monterey + | – (built-in) |
| Swift | 5.9 + | `brew install swift` |
| Xcode Command Line Tools | latest | `xcode-select --install` |

> Homebrew is highly recommended: <https://brew.sh>

---

## Building & Running Locally

```bash
# 1. Clone the repo
$ git clone https://github.com/yourname/chocoya-tadadak.git
$ cd chocoya-tadadak

# 2. Build the app (debug)
$ swift build

# 3. Run it
$ swift run
```

The first launch will ask for **Accessibility** permission so Chocoya Tadadak can listen for key presses. Grant it in

*System Settings → Privacy & Security → Accessibility*.

---

## Packaging a Release Build

```bash
# Build a release binary
$ swift build -c release

# The resulting app bundle is located at
.build/release/ChocoyaTadadak.app
```

The menu-bar icon defaults to the bundled PNG `Resources/chocoya-tadadak.png`. Replace this file with any *template* PNG (monochrome, transparent background) to customize.

---

## Folder Structure (excerpt)

```
Sources/
  └─ TicklingsApp/          # SwiftPM target (executable)
      ├─ Resources/         # Sound themes & icon
      │   ├─ chocoya-tadadak.png
      │   └─ …             # Bubble/, Mechanical/, …
      ├─ AppDelegate.swift  # Menu-bar / event tap set-up
      └─ …
Package.swift               # SwiftPM manifest
```

---

## License

MIT © 2025 Jelly
