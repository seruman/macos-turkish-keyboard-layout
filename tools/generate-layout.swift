import Cocoa
import Carbon

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

func escapeXML(_ s: String) -> String {
    var result = s
    result = result.replacingOccurrences(of: "&", with: "&amp;")
    result = result.replacingOccurrences(of: "<", with: "&lt;")
    result = result.replacingOccurrences(of: ">", with: "&gt;")
    result = result.replacingOccurrences(of: "\"", with: "&quot;")
    return result
}

func generateLayout(from layout: TISInputSource) -> String {
    let layoutData = TISGetInputSourceProperty(layout, kTISPropertyUnicodeKeyLayoutData)
    guard let data = layoutData else {
        fputs("No layout data\n", stderr)
        exit(1)
    }

    let keyboardLayout = unsafeBitCast(data, to: CFData.self)
    let keyLayoutPtr = unsafeBitCast(CFDataGetBytePtr(keyboardLayout), to: UnsafePointer<UCKeyboardLayout>.self)

    // Modifier states: index -> (name, modState)
    // Index 0: none, 1: shift, 2: ctrl, 3: opt, 4: opt+shift
    let modifierStates: [(UInt32)] = [
        0,                                      // 0: none
        UInt32(shiftKey >> 8),                  // 1: shift
        UInt32(controlKey >> 8),                // 2: ctrl
        UInt32(optionKey >> 8),                 // 3: opt
        UInt32((optionKey | shiftKey) >> 8),    // 4: opt+shift
    ]

    // Get character for keycode + modifier
    func getChar(_ keyCode: UInt16, _ modState: UInt32) -> UniChar? {
        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var actualLength: Int = 0
        let status = UCKeyTranslate(
            keyLayoutPtr, keyCode, UInt16(kUCKeyActionDown), modState,
            UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysMask),
            &deadKeyState, chars.count, &actualLength, &chars
        )
        if status == noErr && actualLength > 0 && chars[0] >= 32 {
            return chars[0]
        }
        return nil
    }

    // Build keymaps
    var keyMaps: [[UInt16: UniChar]] = Array(repeating: [:], count: 5)

    for keyCode: UInt16 in 0..<128 {
        for (idx, modState) in modifierStates.enumerated() {
            if let ch = getChar(keyCode, modState) {
                // FIX: For ctrl (index 2), use unshifted value (index 0) instead
                if idx == 2 {
                    if let unshifted = getChar(keyCode, modifierStates[0]) {
                        keyMaps[idx][keyCode] = unshifted
                    }
                } else {
                    keyMaps[idx][keyCode] = ch
                }
            }
        }
    }

    // Generate XML
    var xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE keyboard SYSTEM "file://localhost/System/Library/DTDs/KeyboardLayout.dtd">
    <keyboard group="126" id="-28000" name="Turkish Q Legacy (Fixed)" maxout="1">
    \t<layouts>
    \t\t<layout first="0" last="17" modifiers="common" mapSet="ANSI" />
    \t</layouts>
    \t<modifierMap id="common" defaultIndex="0">
    \t\t<keyMapSelect mapIndex="0">
    \t\t\t<modifier keys="caps?" />
    \t\t</keyMapSelect>
    \t\t<keyMapSelect mapIndex="1">
    \t\t\t<modifier keys="anyShift caps?" />
    \t\t</keyMapSelect>
    \t\t<keyMapSelect mapIndex="2">
    \t\t\t<modifier keys="anyControl caps?" />
    \t\t</keyMapSelect>
    \t\t<keyMapSelect mapIndex="3">
    \t\t\t<modifier keys="anyOption caps?" />
    \t\t</keyMapSelect>
    \t\t<keyMapSelect mapIndex="4">
    \t\t\t<modifier keys="anyOption anyShift caps?" />
    \t\t</keyMapSelect>
    \t</modifierMap>
    \t<keyMapSet id="ANSI">

    """

    let indexNames = ["No modifiers", "Shift", "Control", "Option", "Option+Shift"]

    for (idx, name) in indexNames.enumerated() {
        xml += "\t\t<!-- Index \(idx): \(name) -->\n"
        xml += "\t\t<keyMap index=\"\(idx)\">\n"

        let sortedKeys = keyMaps[idx].keys.sorted()
        for keyCode in sortedKeys {
            if let ch = keyMaps[idx][keyCode] {
                let output = escapeXML(String(Character(UnicodeScalar(ch)!)))
                xml += "\t\t\t<key code=\"\(keyCode)\" output=\"\(output)\"/>\n"
            }
        }
        xml += "\t\t</keyMap>\n"
    }

    xml += "\t</keyMapSet>\n</keyboard>\n"
    return xml
}

guard let layout = findLayout(named: "Turkish Q – Legacy") else {
    fputs("Error: Turkish Q – Legacy layout not found\n", stderr)
    exit(1)
}

let xml = generateLayout(from: layout)
try! xml.write(toFile: "TurkishQLegacyFixed.keylayout", atomically: true, encoding: .utf8)
print("Wrote TurkishQLegacyFixed.keylayout")
