import Carbon
import Foundation

let modifierKeyCodes: Set<UInt16> = [
    55, // Command
    56, // Shift
    57, // Caps Lock
    58, // Option
    59, // Control
    60, // Right Shift
    61, // Right Option
    62, // Right Control
    63, // Fn
]

let fixedControlKeyCodes: Set<UInt16> = [24, 39, 41] // =, ', ;

struct ModifierCombo {
    let index: Int
    let keysString: String
    let carbonMask: UInt32
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

func escapeXML(_ char: UniChar) -> String {
    return String(format: "&#x%04X;", char)
}

func keyboardLayoutPointer(for layout: TISInputSource) -> UnsafePointer<UCKeyboardLayout> {
    guard let layoutData = TISGetInputSourceProperty(layout, kTISPropertyUnicodeKeyLayoutData) else {
        fputs("No layout data\n", stderr)
        exit(1)
    }

    let keyboardLayout = unsafeBitCast(layoutData, to: CFData.self)
    return unsafeBitCast(CFDataGetBytePtr(keyboardLayout), to: UnsafePointer<UCKeyboardLayout>.self)
}

func getChar(_ keyLayoutPtr: UnsafePointer<UCKeyboardLayout>, _ keyCode: UInt16, _ modState: UInt32) -> UniChar? {
    var deadKeyState: UInt32 = 0
    var chars = [UniChar](repeating: 0, count: 4)
    var actualLength: Int = 0
    let status = UCKeyTranslate(
        keyLayoutPtr,
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
        return chars[0]
    }
    return nil
}

func captureMap(_ keyLayoutPtr: UnsafePointer<UCKeyboardLayout>, modState: UInt32) -> [UInt16: UniChar] {
    var result: [UInt16: UniChar] = [:]
    for keyCode: UInt16 in 0..<128 {
        if modifierKeyCodes.contains(keyCode) { continue }
        if let ch = getChar(keyLayoutPtr, keyCode, modState) {
            result[keyCode] = ch
        }
    }
    return result
}

func buildKeyMapXML(index: Int, map: [UInt16: UniChar], indent: String) -> String {
    var lines: [String] = []
    lines.append("\(indent)<keyMap index=\"\(index)\">")
    for keyCode in map.keys.sorted() {
        if let ch = map[keyCode] {
            lines.append("\(indent)\t<key code=\"\(keyCode)\" output=\"\(escapeXML(ch))\"/>")
        }
    }
    lines.append("\(indent)</keyMap>")
    return lines.joined(separator: "\n")
}

let sourceLayoutName = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Turkish Q – Legacy"
let outputLayoutName = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "Turkish Q – Legacy (Fixed)"
let outputPath = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "TurkishQLegacyFixed.keylayout"

guard let sourceLayout = findLayout(named: sourceLayoutName) else {
    fputs("Error: '\(sourceLayoutName)' layout not found\n", stderr)
    exit(1)
}

let keyLayoutPtr = keyboardLayoutPointer(for: sourceLayout)

let shiftMod = UInt32(shiftKey >> 8)
let capsMod = UInt32(alphaLock >> 8)
let optionMod = UInt32(optionKey >> 8)
let commandMod = UInt32(cmdKey >> 8)
let controlMod = UInt32(controlKey >> 8)

let combos: [ModifierCombo] = [
    .init(index: 0, keysString: "", carbonMask: 0),
    .init(index: 1, keysString: "anyShift", carbonMask: shiftMod),
    .init(index: 2, keysString: "caps", carbonMask: capsMod),
    .init(index: 3, keysString: "caps anyShift", carbonMask: capsMod | shiftMod),
    .init(index: 4, keysString: "anyOption", carbonMask: optionMod),
    .init(index: 5, keysString: "anyOption anyShift", carbonMask: optionMod | shiftMod),
    .init(index: 6, keysString: "caps anyOption", carbonMask: capsMod | optionMod),
    .init(index: 7, keysString: "caps anyOption anyShift", carbonMask: capsMod | optionMod | shiftMod),
    .init(index: 8, keysString: "command", carbonMask: commandMod),
    .init(index: 9, keysString: "command anyShift", carbonMask: commandMod | shiftMod),
    .init(index: 10, keysString: "caps command", carbonMask: capsMod | commandMod),
    .init(index: 11, keysString: "caps command anyShift", carbonMask: capsMod | commandMod | shiftMod),
    .init(index: 12, keysString: "command anyOption", carbonMask: commandMod | optionMod),
    .init(index: 13, keysString: "command anyOption anyShift", carbonMask: commandMod | optionMod | shiftMod),
    .init(index: 14, keysString: "caps command anyOption", carbonMask: capsMod | commandMod | optionMod),
    .init(index: 15, keysString: "caps command anyOption anyShift", carbonMask: capsMod | commandMod | optionMod | shiftMod),
]

var mapsByIndex: [Int: [UInt16: UniChar]] = [:]
for combo in combos {
    mapsByIndex[combo.index] = captureMap(keyLayoutPtr, modState: combo.carbonMask)
}

let baseMap = mapsByIndex[0] ?? [:]
var controlMap = captureMap(keyLayoutPtr, modState: controlMod)
for keyCode in fixedControlKeyCodes {
    if let baseChar = baseMap[keyCode] {
        controlMap[keyCode] = baseChar
    }
}
mapsByIndex[16] = controlMap

var keyMapSelectLines: [String] = []
keyMapSelectLines.append("\t\t<keyMapSelect mapIndex=\"16\">\n\t\t\t<modifier keys=\"anyShift? caps? anyOption? command? anyControl\"/>\n\t\t</keyMapSelect>")
for combo in combos.sorted(by: { $0.index > $1.index }) {
    keyMapSelectLines.append("\t\t<keyMapSelect mapIndex=\"\(combo.index)\">\n\t\t\t<modifier keys=\"\(combo.keysString)\"/>\n\t\t</keyMapSelect>")
}

let keyMapXML = (0...16).map { idx in
    buildKeyMapXML(index: idx, map: mapsByIndex[idx] ?? [:], indent: "\t\t")
}.joined(separator: "\n")

let xml = """
<?xml version="1.1" encoding="UTF-8"?>
<!DOCTYPE keyboard SYSTEM "file://localhost/System/Library/DTDs/KeyboardLayout.dtd">
<!--
    \(outputLayoutName)
    Based on \(sourceLayoutName), generated with UCKeyTranslate snapshots.
    Fix: Control layer for key codes 24 (=), 39 ('), 41 (;) uses unshifted output.
-->
<keyboard group="126" id="-28000" name="\(outputLayoutName)">
\t<layouts>
\t\t<layout first="0" last="207" modifiers="modifiers" mapSet="ANSI"/>
\t</layouts>
\t<modifierMap id="modifiers" defaultIndex="0">
\(keyMapSelectLines.joined(separator: "\n"))
\t</modifierMap>
\t<keyMapSet id="ANSI">
\(keyMapXML)
\t</keyMapSet>
</keyboard>
"""

try! xml.write(toFile: outputPath, atomically: true, encoding: .utf8)
print("Wrote \(outputPath)")
