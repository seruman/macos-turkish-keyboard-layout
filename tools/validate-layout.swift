import Carbon
import Foundation

let fixedKeyCodes: Set<UInt16> = [24, 39, 41] // =, ', ;

struct ModCase {
    let name: String
    let state: UInt32
    let hasControl: Bool
}

func findLayout(named targetName: String) -> TISInputSource? {
    let conditions = [kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource] as CFDictionary
    guard let sources = TISCreateInputSourceList(conditions, true)?.takeRetainedValue() as? [TISInputSource] else {
        return nil
    }
    for source in sources {
        if let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
            let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
            if name == targetName {
                return source
            }
        }
    }
    return nil
}

func keyboardLayoutPointer(for layout: TISInputSource) -> UnsafePointer<UCKeyboardLayout>? {
    guard let layoutData = TISGetInputSourceProperty(layout, kTISPropertyUnicodeKeyLayoutData) else {
        return nil
    }
    let keyboardLayout = unsafeBitCast(layoutData, to: CFData.self)
    return unsafeBitCast(CFDataGetBytePtr(keyboardLayout), to: UnsafePointer<UCKeyboardLayout>.self)
}

func charFor(_ ptr: UnsafePointer<UCKeyboardLayout>, keyCode: UInt16, modState: UInt32) -> Int? {
    var deadKeyState: UInt32 = 0
    var chars = [UniChar](repeating: 0, count: 4)
    var actualLength: Int = 0
    let status = UCKeyTranslate(
        ptr,
        keyCode,
        UInt16(kUCKeyActionDown),
        modState,
        UInt32(LMGetKbdType()),
        UInt32(kUCKeyTranslateNoDeadKeysMask),
        &deadKeyState,
        chars.count,
        &actualLength,
        &chars
    )
    if status == noErr && actualLength > 0 {
        return Int(chars[0])
    }
    return nil
}

let sourceName = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Turkish Q – Legacy"
let fixedName = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Turkish Q – Legacy (Fixed)"

guard let source = findLayout(named: sourceName),
      let fixed = findLayout(named: fixedName),
      let sourcePtr = keyboardLayoutPointer(for: source),
      let fixedPtr = keyboardLayoutPointer(for: fixed) else {
    fputs("Error: could not resolve layouts or keyboard layout pointers\n", stderr)
    exit(1)
}

let shift = UInt32(shiftKey >> 8)
let caps = UInt32(alphaLock >> 8)
let option = UInt32(optionKey >> 8)
let command = UInt32(cmdKey >> 8)
let control = UInt32(controlKey >> 8)

let modCases: [ModCase] = [
    .init(name: "none", state: 0, hasControl: false),
    .init(name: "shift", state: shift, hasControl: false),
    .init(name: "caps", state: caps, hasControl: false),
    .init(name: "caps+shift", state: caps | shift, hasControl: false),
    .init(name: "opt", state: option, hasControl: false),
    .init(name: "opt+shift", state: option | shift, hasControl: false),
    .init(name: "caps+opt", state: caps | option, hasControl: false),
    .init(name: "caps+opt+shift", state: caps | option | shift, hasControl: false),
    .init(name: "cmd", state: command, hasControl: false),
    .init(name: "cmd+shift", state: command | shift, hasControl: false),
    .init(name: "cmd+caps", state: command | caps, hasControl: false),
    .init(name: "cmd+caps+shift", state: command | caps | shift, hasControl: false),
    .init(name: "cmd+opt", state: command | option, hasControl: false),
    .init(name: "cmd+opt+shift", state: command | option | shift, hasControl: false),
    .init(name: "ctrl", state: control, hasControl: true),
    .init(name: "ctrl+shift", state: control | shift, hasControl: true),
    .init(name: "ctrl+opt", state: control | option, hasControl: true),
    .init(name: "ctrl+cmd", state: control | command, hasControl: true),
]

var violations: [String] = []

for modCase in modCases {
    for keyCode: UInt16 in 0..<128 {
        let sourceChar = charFor(sourcePtr, keyCode: keyCode, modState: modCase.state)
        let fixedChar = charFor(fixedPtr, keyCode: keyCode, modState: modCase.state)

        if !modCase.hasControl {
            if sourceChar != fixedChar {
                violations.append("[\(modCase.name)] key \(keyCode): source=\(sourceChar.map(String.init) ?? "-") fixed=\(fixedChar.map(String.init) ?? "-")")
            }
            continue
        }

        if fixedKeyCodes.contains(keyCode) {
            let sourceBase = charFor(sourcePtr, keyCode: keyCode, modState: 0)
            if fixedChar != sourceBase {
                violations.append("[\(modCase.name)] key \(keyCode): expected base=\(sourceBase.map(String.init) ?? "-") fixed=\(fixedChar.map(String.init) ?? "-")")
            }
        } else if fixedChar != sourceChar {
            violations.append("[\(modCase.name)] key \(keyCode): source=\(sourceChar.map(String.init) ?? "-") fixed=\(fixedChar.map(String.init) ?? "-")")
        }
    }
}

if violations.isEmpty {
    print("✅ Validation passed")
    print("   - Non-control mappings are identical to '\(sourceName)'")
    print("   - Control mappings differ only on key codes 24, 39, 41 and match base layer")
    exit(0)
}

print("❌ Validation failed: \(violations.count) mismatch(es)")
for line in violations.prefix(50) {
    print("  \(line)")
}
if violations.count > 50 {
    print("  ... and \(violations.count - 50) more")
}
exit(1)
