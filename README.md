# macOS Turkish Keyboard Layout Fix

A fixed version of Apple's Turkish Q Legacy keyboard layout.

## The Bug

Apple's built-in Turkish Q Legacy layout has incorrect Control modifier mappings. When you press `Ctrl+;`, `Ctrl+'`, or `Ctrl+=`, macOS returns the **shifted** character instead of the unshifted one:

| Key | Expected | Actual |
|-----|----------|--------|
| `Ctrl+;` | `;` (59) | `:` (58) |
| `Ctrl+'` | `'` (39) | `"` (34) |
| `Ctrl+=` | `=` (61) | `+` (43) |

This breaks keyboard shortcuts in terminal emulators (Ghostty, WezTerm) and any app using these key combinations.

The bug is in Apple's compiled keyboard layout data (`AppleKeyboardLayouts-L.dat`), not in individual applications. See [docs/turkish-layout-bug.md](docs/turkish-layout-bug.md) for technical details.

## Generate + Validate + Install

```bash
# 1) Generate from the currently installed Apple layout
swift tools/generate-layout.swift

# 2) Install to user layouts (home)
mkdir -p "$HOME/Library/Keyboard Layouts"
cp TurkishQLegacyFixed.keylayout "$HOME/Library/Keyboard Layouts/TurkishQLegacyFixed.keylayout"

# 3) Validate behavior against built-in Turkish Q – Legacy
swift tools/validate-layout.swift

# 4) Add it in System Settings
# System Settings → Keyboard → Input Sources → Edit → +
# Then select: Turkish Q – Legacy (Fixed)
# If it does not show immediately, log out/in IDK.
```
