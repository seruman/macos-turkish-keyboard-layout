# Details

The bug is in `UCKeyTranslate()`, the low-level Carbon API that macOS uses to translate key codes to characters. When called with the Control modifier flag, it returns the shifted character instead of the unshifted one for these specific keys.

## Affected Keys

| KeyCode | none | shift | US+Ctrl | TR+Ctrl | Bug |
|---------|------|-------|---------|---------|-----|
| 24 | `=` (61) | `+` (43) | `=` (61) | `+` (43) | Ctrl produces shifted |
| 39 | `'` (39) | `"` (34) | `'` (39) | `"` (34) | Ctrl produces shifted |
| 41 | `;` (59) | `:` (58) | `;` (59) | `:` (58) | Ctrl produces shifted |

## Test Code

```swift
UCKeyTranslate(
    keyLayoutPtr,
    41,  // semicolon key
    UInt16(kUCKeyActionDown),
    UInt32(controlKey >> 8),  // Control modifier
    UInt32(LMGetKbdType()),
    UInt32(kUCKeyTranslateNoDeadKeysMask),
    &deadKeyState,
    chars.count,
    &actualLength,
    &chars
)
// Returns ':' (58) for Turkish Q Legacy
// Returns ';' (59) for US/ABC layout
```

## Impact

This bug affects any application that:
1. Uses `NSEvent.characters` with Control modifier
2. Relies on `UCKeyTranslate` for key translation
3. Implements keyboard shortcuts using these keys

Terminal emulators like Ghostty and WezTerm encode `Ctrl+;` as CSI u sequences, which breaks with this layout.

## Root Cause

The bug is in Apple's compiled keyboard layout data:
- File: `/System/Library/Keyboard Layouts/AppleKeyboardLayouts.bundle/Contents/Resources/AppleKeyboardLayouts-L.dat`
- Layout: `Turkish-QWERTY-PC` (Turkish Q Legacy)

The layout data has incorrect modifier state mappings for the Control key.

## Full Key Matrices

- [US Layout Matrix](us_layout_matrix.csv)
- [Turkish Q Legacy Matrix](turkish_q_legacy_matrix.csv)
