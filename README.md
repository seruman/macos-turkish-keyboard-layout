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

## Installation

```bash
# Copy layout
mkdir -p "$HOME/Library/Keyboard Layouts"
cp TurkishQLegacyFixed.keylayout "$HOME/Library/Keyboard Layouts/"

# Enable without logout
swift install-layout.swift "Turkish Q Legacy (Fixed)"
```

The layout appears in System Settings > Keyboard > Input Sources as "Turkish Q Legacy (Fixed)".
