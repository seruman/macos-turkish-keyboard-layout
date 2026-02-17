import Cocoa
import Carbon

func csvField(_ s: String) -> String {
    if s.contains(",") || s.contains("\"") {
        return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
    return s
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

func exportMatrix(layout: TISInputSource, name: String) -> String {
    let layoutData = TISGetInputSourceProperty(layout, kTISPropertyUnicodeKeyLayoutData)
    guard let data = layoutData else {
        return ""
    }

    let keyboardLayout = unsafeBitCast(data, to: CFData.self)
    let keyLayoutPtr = unsafeBitCast(CFDataGetBytePtr(keyboardLayout), to: UnsafePointer<UCKeyboardLayout>.self)

    let modifierStates: [(String, UInt32)] = [
        ("none", 0),
        ("shift", UInt32(shiftKey >> 8)),
        ("ctrl", UInt32(controlKey >> 8)),
        ("ctrl+shift", UInt32((controlKey | shiftKey) >> 8)),
        ("opt", UInt32(optionKey >> 8)),
        ("opt+shift", UInt32((optionKey | shiftKey) >> 8)),
    ]

    var lines: [String] = []
    lines.append("keyCode," + modifierStates.map { $0.0 }.joined(separator: ","))

    for keyCode: UInt16 in 0..<128 {
        var fields = ["\(keyCode)"]
        var hasOutput = false

        for (_, modState) in modifierStates {
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
                let cp = chars[0]
                if cp >= 32 && cp < 127 {
                    fields.append(csvField("\(Character(UnicodeScalar(cp)!)) (\(cp))"))
                    hasOutput = true
                } else if cp >= 127 {
                    fields.append(csvField("\\u\(String(format: "%04X", cp)) (\(cp))"))
                    hasOutput = true
                } else {
                    fields.append("^(\(cp))")
                }
            } else {
                fields.append("-")
            }
        }

        if hasOutput {
            lines.append(fields.joined(separator: ","))
        }
    }

    return lines.joined(separator: "\n") + "\n"
}

let layouts: [(name: String, file: String)] = [
    ("Turkish Q – Legacy", "docs/turkish_q_legacy_matrix.csv"),
    ("U.S.", "docs/us_layout_matrix.csv"),
]

for (name, file) in layouts {
    guard let layout = findLayout(named: name) else {
        fputs("Error: Layout '\(name)' not found\n", stderr)
        continue
    }
    let csv = exportMatrix(layout: layout, name: name)
    do {
        try csv.write(toFile: file, atomically: true, encoding: .utf8)
        print("Wrote \(file)")
    } catch {
        fputs("Error writing \(file): \(error)\n", stderr)
    }
}
